import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../domain/permission.dart';
import '../infra/permission_overrides_repository.dart';

/// The signed-in user's own override rows.
///
/// Starts from the on-device cache (so it works offline), then asks the server
/// once the user is known, and again whenever [refresh] is called (after an
/// admin edits their own overrides). A failed refresh keeps what is cached.
class PermissionOverridesNotifier extends Notifier<PermissionOverrides> {
  String? _scope;

  @override
  PermissionOverrides build() {
    final userId = ref.watch(authStateProvider.select((a) => a.userId));
    if (userId == null || userId.isEmpty) {
      _scope = null;
      return const {};
    }
    _scope = '${SyncContext.tenantId ?? 'none'}:$userId';
    final cached = ref.read(permissionOverridesCacheProvider).load(_scope!);
    Future.microtask(refresh);
    return cached;
  }

  /// Re-reads the signed-in user's rows from the server. Safe to call at any
  /// time; offline or failing, it leaves the current value alone.
  Future<void> refresh() async {
    final scope = _scope;
    if (scope == null) return;
    try {
      final fresh =
          await ref.read(permissionOverridesRepositoryProvider).fetchMine();
      if (fresh == null || !ref.mounted || _scope != scope) return;
      state = fresh;
      await ref.read(permissionOverridesCacheProvider).save(scope, fresh);
    } catch (e) {
      debugPrint('permission overrides refresh failed: ${e.runtimeType}');
    }
  }
}

final permissionOverridesProvider =
    NotifierProvider<PermissionOverridesNotifier, PermissionOverrides>(
  PermissionOverridesNotifier.new,
);

/// The signed-in user's role plus their overrides.
class EffectivePermissions {
  const EffectivePermissions(this.role, [this.overrides = const {}]);

  final UserRole? role;
  final PermissionOverrides overrides;

  bool can(Permission permission) =>
      resolvePermission(role, permission, overrides);
}

final effectivePermissionsProvider = Provider<EffectivePermissions>((ref) {
  final role = ref.watch(authStateProvider.select((a) => a.currentRole));
  final overrides = ref.watch(permissionOverridesProvider);
  return EffectivePermissions(role, overrides);
});

/// Whether the signed-in user currently has [permission] (role default with
/// their overrides applied). The named providers below (`canSignOffProvider`,
/// `canManageInventoryProvider`, ...) are thin wrappers over this.
final hasPermissionProvider = Provider.family<bool, Permission>(
  (ref, permission) => ref.watch(
    effectivePermissionsProvider.select((e) => e.can(permission)),
  ),
);
