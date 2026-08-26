import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/domain/entities/tenant_member_entity.dart';
import '../../admin/infra/repositories/admin_repository_impl.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../domain/entities/vehicle_entity.dart';
import '../infra/repositories/vehicle_repository_impl.dart';

/// Whether the signed-in user manages the fleet, as opposed to being stationed
/// to one vehicle.
///
/// Mirrors the database's `can_manage_tenant_work()`, which is
/// admin/supervisor/dispatcher. Kept as one expression so the client rule and
/// the SQL rule can be compared at a glance rather than being spelled out at
/// each call site.
final fleetManagerProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider).currentRole;
  return role == UserRole.admin ||
      role == UserRole.supervisor ||
      role == UserRole.dispatcher;
});

/// The vehicles the signed-in user may see.
///
/// A manager sees the whole fleet; a technician sees only the vehicle they are
/// stationed to. RLS enforces the same split server-side, so a tech's device
/// never receives another vehicle in the first place — this narrows the local
/// Hive copy as well, which matters after a role change on a device that had
/// already cached the fleet.
final fleetVisibleVehiclesProvider =
    FutureProvider<List<VehicleEntity>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  if (ref.watch(fleetManagerProvider)) return repository.list();

  final userId = ref.watch(authStateProvider).userId;
  // No session means nothing to scope by. Returning the whole fleet here would
  // be the one case where an unauthenticated read sees everything.
  if (userId == null || userId.isEmpty) return const [];

  return repository.list(assignedToUserId: userId);
});

final vehicleProvider = FutureProvider.family<VehicleEntity?, String>(
  (ref, id) => ref.watch(vehicleRepositoryProvider).getById(id),
);

/// People who can be stationed to a vehicle.
///
/// Read from `tenant_members`, **not** from `listTechnicians()`: the legacy
/// `technicians` table's `id` is its own row id, while `assigned_to_user_id`
/// references `auth.users`. Assigning from that list would store an id the
/// foreign key rejects and RLS could never match.
///
/// Not filtered to tech. The requirement is that a technician is *stationed*
/// to a vehicle, not that nobody else may be — a supervisor who drives a truck
/// is ordinary, and they already have manager visibility either way.
///
/// Assignment stays optional: dispatch adds a vehicle to the fleet before
/// deciding who drives it, and blocking the record on that would push it onto
/// a whiteboard.
final fleetAssignableMembersProvider =
    FutureProvider<List<TenantMemberEntity>>((ref) async {
  final members = await ref.watch(adminRepositoryProvider).listTenantMembers();
  return members.where((member) => member.isActive).toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
});
