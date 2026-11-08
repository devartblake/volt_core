import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/readiness/domain/readiness_export_data.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_services.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository.dart';

import 'readiness_fixtures.dart';
import 'ui/readiness_ui_harness.dart' show FakeScheduler, fleetInputs;

class _Repo implements ScheduleRepository {
  final saved = <TaskScheduleEntity>[];
  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity t) async {
    saved.add(t);
    return t;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

ReadinessReport _report() =>
    computeReadiness(fleetInputs(), const ReadinessConfig(), kNow);

void main() {
  group('scheduling', () {
    test('creates an inspection task linked to the latest inspection', () async {
      final repo = _Repo();
      var reloads = 0;
      final scheduler =
          RepositoryReadinessScheduler(repo, onReload: () async => reloads++);
      final u = _report().units.firstWhere((x) => x.serial == 'S3');

      await scheduler.scheduleInspection(u, DateTime(2026, 11, 20, 15));
      await scheduler.reload();

      final t = repo.saved.single;
      expect(t.sourceType, 'inspection');
      expect(t.sourceId, 'i3');
      expect(t.inspectionId, 'i3');
      expect(t.siteCode, 'X_003');
      expect(t.status, 'scheduled');
      expect(t.scheduledDate, DateTime(2026, 11, 20));
      expect(t.scheduledAt, DateTime(2026, 11, 20, 8));
      expect(t.id, isNotEmpty);
      expect(t.description, contains(u.title));
      expect(reloads, 1);
    });

    test('bulk: one task per unit, failures listed, the rest still saved',
        () async {
      final units = _report().units.take(6).toList();
      final failing = units[2].serial;
      final scheduler = FakeScheduler(failFor: {failing});
      final r =
          await scheduleInspections(scheduler, units, DateTime(2026, 11, 20));
      expect(r.scheduled, 5);
      expect(r.failures.single.key, units[2].title);
      expect(r.summary, 'Scheduled 5 of 6 inspections');
      expect(scheduler.calls, hasLength(5));

      final ok = await scheduleInspections(
          FakeScheduler(), units, DateTime(2026, 11, 20));
      expect(ok.summary, 'Scheduled 6 inspections');
      expect(ok.hasFailures, isFalse);
      expect(
          (await scheduleInspections(FakeScheduler(), units.take(1), kNow))
              .summary,
          'Scheduled 1 inspection');
    });
  });

  test('only dispatch, supervisors and admins may schedule', () {
    expect(canScheduleReadiness(UserRole.tech), isFalse);
    expect(canScheduleReadiness(null), isFalse);
    for (final r in [UserRole.dispatcher, UserRole.supervisor, UserRole.admin]) {
      expect(canScheduleReadiness(r), isTrue);
    }
  });

  test('Fleet Readiness PDF is a real PDF with content', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = _report();
    final data = ReadinessExportData(
      units: r.units,
      summary: summarizeReadiness(r.units, r.now),
      asOf: r.now,
    );
    final bytes = await PdfService.instance.buildReadinessPdfBytes(data);
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(4000));
    expect(latin1.decode(bytes.sublist(bytes.length - 12)), contains('%%EOF'));

    // A filtered subset and an empty fleet build too.
    final subset =
        await PdfService.instance.buildReadinessPdfBytes(ReadinessExportData(
      units: r.units.take(2).toList(),
      summary: data.summary,
      asOf: r.now,
      filtered: true,
    ));
    expect(latin1.decode(subset.sublist(0, 5)), '%PDF-');
    final empty =
        await PdfService.instance.buildReadinessPdfBytes(ReadinessExportData(
      units: const [],
      summary: ReadinessSummary.empty,
      asOf: r.now,
    ));
    expect(empty.length, greaterThan(1000));
  });
}
