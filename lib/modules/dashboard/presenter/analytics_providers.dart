import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../../app/route_roles.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/services/hive/hive_boxes.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../../inspections/infra/models/inspection.dart';
import '../../inventory/domain/stock.dart';
import '../../inventory/infra/inventory_repository.dart';
import '../../maintenance/infra/datasources/hive_boxes_maintenance.dart';
import '../../maintenance/infra/models/maintenance_record.dart';
import '../../schedule/infra/datasources/scheduled_tasks_box.dart';
import '../../schedule/infra/models/schedule_task.dart';
import '../../work_orders/presenter/work_order_providers.dart';
import '../domain/analytics_series.dart';
import '../domain/analytics_snapshot.dart';

/// The period chosen on the Analytics page. Not auto-disposed, so it is
/// remembered for the session.
final analyticsPeriodProvider =
    StateProvider<AnalyticsPeriod>((ref) => AnalyticsPeriod.weeks12);

/// "Now" for Analytics; tests replace it.
final analyticsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bumped by pull-to-refresh to re-read the device data.
final analyticsRefreshProvider = StateProvider<int>((ref) => 0);

/// Reads the device data. Tests replace this with a fake.
final analyticsSnapshotLoaderProvider = Provider<AnalyticsSnapshot Function()>(
  (ref) => readAnalyticsSnapshotFromHive,
);

final analyticsSnapshotProvider = Provider.autoDispose<AnalyticsSnapshot>((ref) {
  ref.watch(analyticsRefreshProvider);
  return ref.watch(analyticsSnapshotLoaderProvider)();
});

/// Inspections, maintenance and schedule from the boxes on this device.
/// Offline-friendly: whatever is stored is used; a box that is not open reads
/// as empty.
AnalyticsSnapshot readAnalyticsSnapshotFromHive() {
  final Iterable<Inspection> inspections = Hive.isBoxOpen(HiveBoxes.inspectionsBoxName)
      ? HiveBoxes.inspections.values
      : const <Inspection>[];
  final Iterable<MaintenanceRecord> maintenance = MaintenanceBoxes.isInitialized
      ? MaintenanceBoxes.maintenance.values
      : const <MaintenanceRecord>[];
  final Iterable<ScheduledTask> tasks = Hive.isBoxOpen(ScheduledTasksBox.boxName)
      ? ScheduledTasksBox.box.values
      : const <ScheduledTask>[];
  return AnalyticsSnapshot(
    inspections: [
      for (final i in inspections)
        InspectionPoint(
          date: i.serviceDate,
          createdAt: i.createdAt,
          grade: i.siteGrade,
          siteCode: i.siteCode,
          deficiencies: i.deficienciesDocumented,
          loadbankDone: i.loadbankDone,
        ),
    ],
    maintenance: [
      for (final m in maintenance)
        MaintenancePoint(
          date: m.dateOfService ?? m.createdAt,
          completed: m.completed,
          requiresFollowUp: m.requiresFollowUp,
        ),
    ],
    tasks: [
      for (final t in tasks)
        TaskPoint(when: t.scheduledAt, status: t.status, assignee: t.assignedToUserId),
    ],
  );
}

/// Which optional charts a role sees.
class AnalyticsAccess {
  const AnalyticsAccess({
    required this.workOrders,
    required this.workload,
    required this.inventory,
  });

  /// Job status chart (a technician sees only their own jobs).
  final bool workOrders;

  /// Tasks per technician: dispatcher and admin only.
  final bool workload;

  /// Parts in stock: admin, supervisor and dispatcher.
  final bool inventory;

  static const none = AnalyticsAccess(workOrders: false, workload: false, inventory: false);

  factory AnalyticsAccess.forRole(UserRole? role) {
    if (role == null) return none;
    return AnalyticsAccess(
      workOrders: RouteRoles.isAllowedByName(name: RouteNames.workOrders, role: role),
      workload: role == UserRole.dispatcher || role == UserRole.admin,
      inventory: role == UserRole.dispatcher ||
          role == UserRole.admin ||
          role == UserRole.supervisor,
    );
  }
}

final analyticsAccessProvider = Provider.autoDispose<AnalyticsAccess>(
  (ref) => AnalyticsAccess.forRole(ref.watch(authStateProvider).currentRole),
);

/// Work orders for the status chart; null when the role has none. A technician
/// sees only the jobs assigned to them, as on the dashboard.
final analyticsOrdersProvider =
    FutureProvider.autoDispose<List<OrderPoint>?>((ref) async {
  final access = ref.watch(analyticsAccessProvider);
  if (!access.workOrders) return null;
  final auth = ref.watch(authStateProvider);
  final orders = await ref.watch(workOrderListProvider.future);
  return [
    for (final o in orders)
      if (auth.currentRole != UserRole.tech || o.assignedToUserId == auth.userId)
        OrderPoint(status: o.status, scheduledFor: o.scheduledFor),
  ];
});

/// Parts by stock state; null when the role cannot see inventory.
final analyticsStockProvider = FutureProvider.autoDispose<StockSplit?>((ref) async {
  if (!ref.watch(analyticsAccessProvider).inventory) return null;
  final levels = await ref.watch(stockLevelsProvider.future);
  var ok = 0, low = 0, out = 0;
  for (final l in levels) {
    switch (l.status) {
      case StockStatus.ok:
        ok++;
      case StockStatus.low:
        low++;
      case StockStatus.out:
        out++;
    }
  }
  return StockSplit(ok: ok, low: low, out: out);
});
