import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../infra/inventory_repository.dart';

/// Who may receive, adjust and count stock and edit the catalog. Admin for
/// now; "super admin" is the same role until the app has one.
bool canManageInventory(UserRole? role) => role == UserRole.admin;

/// Who may set parts aside for a job, issue them and take returns.
bool canReserveStock(UserRole? role) =>
    role == UserRole.admin ||
    role == UserRole.supervisor ||
    role == UserRole.dispatcher;

final canReserveStockProvider = Provider<bool>(
  (ref) => canReserveStock(ref.watch(authStateProvider).currentRole),
);

/// Whether the signed-in user can change inventory.
final canManageInventoryProvider = Provider<bool>(
  (ref) => canManageInventory(ref.watch(authStateProvider).currentRole),
);

/// Pulls the cloud catalog and ledger into the device. Pages invalidate the
/// stock providers when it finishes.
final inventoryRefreshProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(inventoryRepositoryProvider).refreshFromCloud(),
);
