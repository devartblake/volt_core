/// What the readiness screens can DO beyond showing data: schedule an
/// inspection and export. Each is a provider so widget tests substitute a fake
/// (no Hive, no Supabase, no share sheet), like `documentActionsProvider`.
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/pdf/pdf_service.dart';
import '../../auth/domain/user_role.dart';
import '../../schedule/domain/entities/task_schedule_entity.dart';
import '../../schedule/infra/repositories/schedule_repository.dart';
import '../../schedule/presenter/controllers/schedule_controller.dart';
import '../../schedule/infra/repositories/schedule_repository_impl.dart';
import '../domain/readiness_csv.dart';
import '../domain/readiness_export_data.dart';
import '../domain/readiness_models.dart';

/// Scheduling and bulk actions are for dispatchers, supervisors and admins.
/// Technicians see the dashboard read-only.
bool canScheduleReadiness(UserRole? role) =>
    role == UserRole.dispatcher ||
    role == UserRole.supervisor ||
    role == UserRole.admin;

// ---------------------------------------------------------------------------
// Scheduling

abstract class ReadinessScheduler {
  const ReadinessScheduler();

  /// Creates one scheduled inspection task for [unit] on [date]. Throws when
  /// it could not be saved.
  Future<void> scheduleInspection(ReadinessUnit unit, DateTime date);

  /// Refreshes whatever shows scheduled tasks after a change (the Schedule
  /// screen's list). No-op by default.
  Future<void> reload() async {}
}

/// The real path: the same `ScheduleRepository.saveTask` the Schedule screen's
/// "new task" dialog uses (local save, cloud sync queue and reminder included).
class RepositoryReadinessScheduler extends ReadinessScheduler {
  const RepositoryReadinessScheduler(this._repo, {Future<void> Function()? onReload})
      : _onReload = onReload;

  final ScheduleRepository _repo;
  final Future<void> Function()? _onReload;

  @override
  Future<void> reload() async => _onReload?.call();

  @override
  Future<void> scheduleInspection(ReadinessUnit unit, DateTime date) async {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final site = unit.siteCode.isNotEmpty ? unit.siteCode : unit.address;
    final task = TaskScheduleEntity(
      id: const Uuid().v4(),
      tenantId: '',
      title: site.isNotEmpty ? site : unit.title,
      description: 'Inspection scheduled from Fleet readiness: ${unit.title}',
      scheduledAt: DateTime(date.year, date.month, date.day, 8),
      scheduledDate: day,
      status: 'scheduled',
      sourceType: 'inspection',
      // Linking the latest inspection lets the readiness join recognise the
      // task as this unit's next visit (a task never carries a serial).
      sourceId: unit.latestInspectionId ?? '',
      inspectionId: unit.latestInspectionId,
      siteCode: unit.siteCode,
      address: unit.address,
      siteGrade:
          unit.lastGrade == ReadinessGrade.none ? '' : unit.lastGrade.label,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.saveTask(task);
  }
}

final readinessSchedulerProvider = Provider<ReadinessScheduler>(
  (ref) => RepositoryReadinessScheduler(
    ref.watch(scheduleRepositoryProvider),
    onReload: () => ref.read(scheduleControllerProvider.notifier).load(),
  ),
);

/// Outcome of scheduling several units.
class BulkScheduleResult {
  const BulkScheduleResult(this.scheduled, this.failures);

  final int scheduled;

  /// Unit title -> plain reason.
  final List<MapEntry<String, String>> failures;

  bool get hasFailures => failures.isNotEmpty;

  /// "Scheduled 6 inspections", or "Scheduled 4 of 6 inspections".
  String get summary {
    final total = scheduled + failures.length;
    final noun = total == 1 ? 'inspection' : 'inspections';
    return failures.isEmpty
        ? 'Scheduled $scheduled $noun'
        : 'Scheduled $scheduled of $total $noun';
  }
}

/// One task per unit, one date for all. A failure on one unit never stops the
/// others; each failure is listed.
Future<BulkScheduleResult> scheduleInspections(
  ReadinessScheduler scheduler,
  Iterable<ReadinessUnit> units,
  DateTime date,
) async {
  var ok = 0;
  final failures = <MapEntry<String, String>>[];
  for (final u in units) {
    try {
      await scheduler.scheduleInspection(u, date);
      ok++;
    } catch (e) {
      failures.add(MapEntry(u.title, 'Could not be saved'));
      debugPrint('[readiness] schedule ${u.key} failed: $e');
    }
  }
  return BulkScheduleResult(ok, failures);
}

// ---------------------------------------------------------------------------
// Export

abstract class ReadinessExporter {
  const ReadinessExporter();

  /// Shares the CSV. False when the user dismissed the share sheet.
  Future<bool> shareCsv(List<ReadinessUnit> units);

  /// Builds, stores (in the Documents hub) and shares the PDF report.
  Future<bool> sharePdf(ReadinessExportData data);
}

class DefaultReadinessExporter extends ReadinessExporter {
  const DefaultReadinessExporter();

  @override
  Future<bool> shareCsv(List<ReadinessUnit> units) async {
    // A byte order mark so Excel reads the UTF-8 correctly.
    final bytes = Uint8List.fromList(
        [0xEF, 0xBB, 0xBF, ...utf8.encode(readinessCsv(units))]);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final name = 'fleet-readiness-$stamp.csv';
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
      fileNameOverrides: [name],
      subject: 'Fleet readiness',
    ));
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> sharePdf(ReadinessExportData data) async {
    final saved = await PdfService.instance.generateReadinessPdf(data);
    final path = saved.filePath;
    if (path == null || path.isEmpty) return false;
    if (kIsWeb) {
      final bytes = await PdfService.instance.buildReadinessPdfBytes(data);
      await Printing.sharePdf(
          bytes: bytes, filename: 'Fleet_Readiness_Report.pdf');
      return true;
    }
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: 'application/pdf')],
      subject: 'Fleet Readiness Report',
    ));
    // Saved to Documents either way; a dismissed sheet is not an error.
    return result.status != ShareResultStatus.dismissed;
  }
}

final readinessExporterProvider =
    Provider<ReadinessExporter>((ref) => const DefaultReadinessExporter());
