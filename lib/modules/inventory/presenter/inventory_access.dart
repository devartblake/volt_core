import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_role.dart';
import '../../permissions/domain/permission.dart';
import '../../permissions/presenter/permission_providers.dart';
import '../infra/inventory_repository.dart';

/// Who may receive, adjust and count stock and edit the catalog, by role
/// alone (permission `manage_inventory`). Admin for now; "super admin" is the
/// same role until the app has one.
bool canManageInventory(UserRole? role) =>
    Permission.manageInventory.defaultFor(role);

/// Who may set parts aside for a job, issue them and take returns, by role
/// alone (permission `reserve_stock`).
bool canReserveStock(UserRole? role) =>
    Permission.reserveStock.defaultFor(role);

/// Whether the signed-in user can reserve and issue stock (role default plus
/// their overrides).
final canReserveStockProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.reserveStock)),
);

/// Whether the signed-in user can change inventory (role default plus their
/// overrides).
final canManageInventoryProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.manageInventory)),
);

/// Pulls the cloud catalog and ledger into the device. Pages invalidate the
/// stock providers when it finishes.
final inventoryRefreshProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(inventoryRepositoryProvider).refreshFromCloud(),
);
