/// Riverpod layer for Fleet readiness. Thin: gathers records, hands them to
/// the pure `computeReadiness`, and caches the result until a source changes.
///
/// Test seams (override these, no Hive needed):
///  * [readinessInputsProvider]  - the raw records;
///  * [readinessConfigStoreProvider] - where thresholds are saved;
///  * [readinessClockProvider]   - "now".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/settings/app_preferences_service.dart';
import '../../../providers/equipment_providers.dart' as eq;
import '../../auth/domain/user_role.dart';
import '../../customers/customer_site_repository.dart';
import '../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../inventory/presenter/job_needs_providers.dart';
import '../../maintenance/presenter/controllers/maintenance_providers.dart';
import '../../materials/domain/material_item.dart';
import '../../schedule/presenter/controllers/schedule_controller.dart';
import '../domain/readiness_inputs.dart';
import '../domain/readiness_models.dart';
import '../domain/readiness_rules.dart';
import '../domain/readiness_summary.dart';

// ---------------------------------------------------------------------------
// Config

/// Where thresholds live. Default: the app preferences box.
abstract class ReadinessConfigStore {
  ReadinessConfig load();
  Future<void> save(ReadinessConfig config);
}

class PreferencesReadinessConfigStore implements ReadinessConfigStore {
  const PreferencesReadinessConfigStore();

  @override
  ReadinessConfig load() {
    final p = AppPreferencesService.instance;
    return ReadinessConfig(
      dueSoonDays: p.readinessDueSoonDays,
      criticalOverdueDays: p.readinessCriticalOverdueDays,
    );
  }

  @override
  Future<void> save(ReadinessConfig config) async {
    final p = AppPreferencesService.instance;
    await p.setReadinessDueSoonDays(config.dueSoonDays);
    await p.setReadinessCriticalOverdueDays(config.criticalOverdueDays);
  }
}

final readinessConfigStoreProvider = Provider<ReadinessConfigStore>(
  (ref) => const PreferencesReadinessConfigStore(),
);

/// Only admins may change the thresholds.
bool canEditReadinessConfig(UserRole? role) => role == UserRole.admin;

class ReadinessConfigController extends StateNotifier<ReadinessConfig> {
  ReadinessConfigController(this._store) : super(_store.load());

  final ReadinessConfigStore _store;

  /// Saves [config] (days clamped to 0..3650) when [role] is admin; returns
  /// false and changes nothing otherwise.
  Future<bool> update(ReadinessConfig config, {required UserRole? role}) async {
    if (!canEditReadinessConfig(role)) return false;
    int c(int v) => v.clamp(0, 3650);
    final next = config.copyWith(
      dueSoonDays: c(config.dueSoonDays),
      criticalOverdueDays: c(config.criticalOverdueDays),
      staleInspectionDays: c(config.staleInspectionDays),
      loadTestIntervalDays: c(config.loadTestIntervalDays),
    );
    await _store.save(next);
    state = next;
    return true;
  }
}

/// The thresholds. Read `.value`-free: it is a plain state provider.
final readinessConfigProvider = StateNotifierProvider.autoDispose<
    ReadinessConfigController, ReadinessConfig>(
  (ref) => ReadinessConfigController(ref.watch(readinessConfigStoreProvider)),
);

/// "Now" for the computation; override in tests.
final readinessClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// Inputs

String _plain(String? s) => s ?? '';

/// Gathers the raw records. Each source is best effort: one that fails to load
/// (no tenant, box not open, offline) is skipped and the rest are used.
final readinessInputsProvider =
    FutureProvider.autoDispose<ReadinessInputs>((ref) async {
  var inspections = const <ReadinessInspection>[];
  var maintenance = const <ReadinessMaintenance>[];
  var tasks = const <ReadinessTask>[];
  var equipment = const <ReadinessEquipment>[];
  var sites = const <ReadinessSite>[];
  var jobNeeds = const <ReadinessJobNeed>[];

  try {
    inspections = [
      for (final i in ref.watch(inspectionListControllerProvider).items)
        ReadinessInspection(
          id: i.id,
          serviceDate: i.serviceDate,
          siteCode: i.siteCode,
          address: i.address,
          grade: i.siteGrade,
          nextDueAt: i.nextDueAt,
          make: i.generatorMake,
          model: i.generatorModel,
          serial: i.generatorSerial,
          fuelType: i.fuelType,
          loadbankDone: i.loadbankDone,
          updatedAt: i.updatedAt,
        ),
    ];
  } catch (_) {}

  try {
    maintenance = [
      for (final m in ref.watch(maintenanceRepoProvider).getAll())
        ReadinessMaintenance(
          id: m.id,
          inspectionId: m.inspectionId,
          siteCode: m.siteCode,
          address: m.address,
          make: m.generatorMake,
          model: m.generatorModel,
          serial: m.generatorSerial,
          date: m.dateOfService ?? m.createdAt,
          completed: m.completed,
          requiresFollowUp: m.requiresFollowUp,
          followUpNotes: _plain(m.followUpNotes),
        ),
    ];
  } catch (_) {}

  try {
    tasks = [
      for (final t in ref.watch(scheduleControllerProvider).value ?? const [])
        ReadinessTask(
          id: t.id,
          scheduledAt: t.scheduledAt,
          siteCode: t.siteCode,
          inspectionId: t.inspectionId,
          sourceType: t.sourceType,
          sourceId: t.sourceId,
          status: t.status,
        ),
    ];
  } catch (_) {}

  try {
    equipment = [
      for (final e in await ref.watch(eq.equipmentListProvider.future))
        ReadinessEquipment(
          id: e.id,
          make: e.make,
          model: e.model,
          serial: e.serialNumber,
          siteCode: e.siteCode,
          location: e.location,
          fuelType: _plain(e.metadata['fuelType']?.toString()),
          isGenerator: e.assetType.name == 'generator',
          isRetired: e.status == eq.EquipmentStatus.retired,
          lastInspection: e.lastInspection,
        ),
    ];
  } catch (_) {}

  try {
    final dir = await ref.watch(customerSiteDirectoryProvider.future);
    final names = {for (final c in dir.customers) c.id: c.name};
    sites = [
      for (final s in dir.sites)
        if (s.isActive)
          ReadinessSite(
            siteCode: s.siteCode,
            address: s.address,
            customerName: names[s.customerId] ?? '',
          ),
    ];
  } catch (_) {}

  try {
    jobNeeds = [
      for (final n in await ref.watch(jobNeedsProvider.future))
        if (n.shortCount > 0)
          ReadinessJobNeed(
            type: n.job.type == MaterialOwnerType.inspection
                ? ReadinessJobType.inspection
                : ReadinessJobType.maintenance,
            jobId: n.job.id,
            shortCount: n.shortCount,
          ),
    ];
  } catch (_) {}

  return ReadinessInputs(
    inspections: inspections,
    maintenance: maintenance,
    tasks: tasks,
    equipment: equipment,
    sites: sites,
    jobNeeds: jobNeeds,
  );
});

// ---------------------------------------------------------------------------
// Results (computed once per input/config change, shared by every widget)

/// Units plus the unmatched-record counts.
final readinessReportProvider =
    FutureProvider.autoDispose<ReadinessReport>((ref) async {
  final inputs = await ref.watch(readinessInputsProvider.future);
  final config = ref.watch(readinessConfigProvider);
  final now = ref.read(readinessClockProvider)();
  return computeReadiness(inputs, config, now);
});

/// Every unit, worst first.
final readinessUnitsProvider =
    Provider.autoDispose<AsyncValue<List<ReadinessUnit>>>(
  (ref) => ref.watch(readinessReportProvider).whenData((r) => r.units),
);

/// Fleet totals.
final readinessSummaryProvider =
    Provider.autoDispose<AsyncValue<ReadinessSummary>>(
  (ref) => ref
      .watch(readinessReportProvider)
      .whenData((r) => summarizeReadiness(r.units, r.now)),
);

// ---------------------------------------------------------------------------
// View state

/// Kept alive on purpose: the filters and sort are remembered for the session
/// when the user leaves the screen and comes back.
final readinessFilterProvider =
    StateProvider<ReadinessFilter>((ref) => const ReadinessFilter());

final readinessSortProvider =
    StateProvider<ReadinessSort>((ref) => ReadinessSort.worstFirst);

/// The units the list shows: filtered, then sorted.
final filteredReadinessUnitsProvider =
    Provider.autoDispose<AsyncValue<List<ReadinessUnit>>>((ref) {
  final filter = ref.watch(readinessFilterProvider);
  final sort = ref.watch(readinessSortProvider);
  return ref
      .watch(readinessUnitsProvider)
      .whenData((all) => sortReadiness(filter.apply(all), sort));
});
