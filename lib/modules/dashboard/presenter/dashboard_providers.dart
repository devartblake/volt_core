import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/route_roles.dart';
import '../../../core/constants/route_paths.dart';
import '../../admin/presenter/controllers/role_management_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../../fleet/domain/entities/vehicle_inspection.dart';
import '../../fleet/infra/repositories/vehicle_inspection_repository.dart';
import '../../fleet/presenter/fleet_providers.dart';
import '../../work_orders/presenter/work_order_providers.dart';
import '../../work_orders/presenter/work_order_workload.dart';

/// How many vehicles have no daily inspection today, or null when this role has
/// no fleet (so the dashboard leaves the item out instead of showing zero).
///
/// For a technician the fleet list is just their own vehicle, so this reads
/// "is my daily check done".
final dailyChecksDueProvider = FutureProvider.autoDispose<int?>((ref) async {
  final role = ref.watch(authStateProvider).currentRole;
  if (role == null ||
      !RouteRoles.isAllowedByName(name: RouteNames.fleet, role: role)) {
    return null;
  }

  final vehicles = await ref.watch(fleetVisibleVehiclesProvider.future);
  if (vehicles.isEmpty) return null;
  final all = await ref.watch(allVehicleInspectionsProvider.future);

  var due = 0;
  for (final vehicle in vehicles) {
    final mine = all.where((i) => i.vehicleId == vehicle.id);
    final status = InspectionStatus.compute(InspectionCadence.daily, mine);
    if (status.state != InspectionDueState.ok) due++;
  }
  return due;
});

/// Job counts for the dashboard. A technician sees only the jobs assigned to
/// them; everyone else sees the tenant's queue. Null when the role has no
/// access to jobs.
final dashboardWorkloadProvider =
    FutureProvider.autoDispose<WorkOrderWorkload?>((ref) async {
  final auth = ref.watch(authStateProvider);
  final role = auth.currentRole;
  if (role == null ||
      !RouteRoles.isAllowedByName(name: RouteNames.workOrders, role: role)) {
    return null;
  }

  final orders = await ref.watch(workOrderListProvider.future);
  final mine = role == UserRole.tech
      ? orders.where((o) => o.assignedToUserId == auth.userId)
      : orders;
  return WorkOrderWorkload.fromOrders(mine, today: DateTime.now());
});

/// Technician names by user id and the ids of active technicians, for the
/// dispatcher's "Who is on what today". Empty when the list cannot be loaded
/// (offline, or no access): rows then fall back to a short id label.
final dashboardTechniciansProvider = FutureProvider.autoDispose<
    ({Map<String, String> names, List<String> roster})>((ref) async {
  try {
    final techs = await ref.watch(listUsersUsecaseProvider).call();
    return (
      names: {for (final t in techs) t.id: t.name},
      roster: [
        for (final t in techs)
          if (t.isActive && t.role == UserRole.tech) t.id,
      ],
    );
  } catch (_) {
    return (names: const <String, String>{}, roster: const <String>[]);
  }
});
