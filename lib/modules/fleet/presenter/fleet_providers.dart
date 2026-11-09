import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage/pdf_library_service.dart';
import '../../admin/domain/entities/tenant_member_entity.dart';
import '../../admin/infra/repositories/admin_repository_impl.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../../permissions/domain/permission.dart';
import '../../permissions/presenter/permission_providers.dart';
import '../domain/entities/vehicle_entity.dart';
import '../domain/entities/vehicle_maintenance_check.dart';
import '../domain/entities/vehicle_asset_catalog_item.dart';
import '../infra/repositories/vehicle_asset_repository.dart';
import '../infra/repositories/vehicle_check_repository.dart';
import '../infra/repositories/vehicle_repository_impl.dart';

/// Whether the signed-in user manages the fleet, as opposed to being stationed
/// to one vehicle.
///
/// Mirrors the database's `can_manage_tenant_work()`, which is
/// admin/supervisor/dispatcher. Kept as one expression so the client rule and
/// the SQL rule can be compared at a glance rather than being spelled out at
/// each call site.
final fleetManagerProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.manageFleet)),
);

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


/// Maintenance history for one vehicle, newest first.
final vehicleChecksProvider =
    FutureProvider.family<List<VehicleMaintenanceCheck>, String>(
  (ref, vehicleId) =>
      ref.watch(vehicleCheckRepositoryProvider).listForVehicle(vehicleId),
);


/// Whether the signed-in user curates the tool catalog.
///
/// Admin only, unlike the rest of the fleet: a sloppy catalog is exactly what
/// splitting catalog from assignment exists to prevent, and the migration gates
/// vehicle_asset_catalog writes on has_tenant_role(..., ['admin']).
final fleetCatalogEditorProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.manageToolCatalog)),
);

/// The tool catalog. Active entries only — a deactivated tool should not be
/// offered when assigning.
final vehicleAssetCatalogProvider =
    FutureProvider<List<VehicleAssetCatalogItem>>(
  (ref) => ref.watch(vehicleAssetRepositoryProvider).listCatalog(),
);

/// The whole catalog including deactivated entries, for the admin screen.
final vehicleAssetCatalogAllProvider =
    FutureProvider<List<VehicleAssetCatalogItem>>(
  (ref) => ref
      .watch(vehicleAssetRepositoryProvider)
      .listCatalog(includeInactive: true),
);

/// Tools in one vehicle, resolved against the catalog.
final vehicleAssetsProvider =
    FutureProvider.family<List<ResolvedVehicleAsset>, String>(
  (ref, vehicleId) =>
      ref.watch(vehicleAssetRepositoryProvider).listForVehicle(vehicleId),
);

/// Saved vehicle PDFs for one vehicle, newest first.
///
/// The vehicle report is stored as `Vehicle_<name>_<date>_<first 8 of id>.pdf`
/// under `vehicles/`, so the id prefix is what ties a file to its vehicle.
final vehicleDocumentsProvider =
    FutureProvider.family<List<PdfDocumentInfo>, String>((ref, vehicleId) async {
  final all = await PdfLibraryService.instance.listDocuments();
  return vehicleDocumentsFor(all, vehicleId);
});

/// Pure filter behind [vehicleDocumentsProvider].
List<PdfDocumentInfo> vehicleDocumentsFor(
  Iterable<PdfDocumentInfo> docs,
  String vehicleId,
) {
  final shortId = vehicleId.length > 8 ? vehicleId.substring(0, 8) : vehicleId;
  if (shortId.isEmpty) return const [];
  return docs
      .where((d) =>
          d.category == PdfCategory.vehicle &&
          d.name.toLowerCase().endsWith('_${shortId.toLowerCase()}.pdf'))
      .toList()
    ..sort((a, b) => b.modified.compareTo(a.modified));
}
