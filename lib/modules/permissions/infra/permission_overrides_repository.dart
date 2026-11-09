import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/connectivity/connectivity_service.dart';
import '../../../core/services/settings/app_preferences_service.dart';
import '../../../core/services/sync/sync_context.dart';
import '../domain/permission.dart';

/// Shown when permissions are changed and the device has no connection.
const String kPermissionsOfflineMessage =
    'Connect to the internet to change permissions.';

class PermissionsOfflineException implements Exception {
  const PermissionsOfflineException();

  @override
  String toString() => kPermissionsOfflineMessage;
}

/// Reads and writes `public.member_permission_overrides`.
abstract class PermissionOverridesRepository {
  /// The signed-in user's own rows, or null when they can not be read (no
  /// tenant configured, offline, table missing). Never throws: it only
  /// decorates the app, which then keeps whatever it cached.
  Future<PermissionOverrides?> fetchMine();

  /// Every override of [userId] in the active company (admin screen). Throws
  /// [PermissionsOfflineException] when offline.
  Future<PermissionOverrides> fetchFor(String userId);

  /// Sets [permission] for [userId]; a null [effect] removes the override
  /// (back to the role default). Online only.
  Future<void> setOverride({
    required String userId,
    required Permission permission,
    required PermissionEffect? effect,
  });

  /// Removes every override of [userId]. Online only.
  Future<void> resetAll(String userId);
}

class SupabasePermissionOverridesRepository
    implements PermissionOverridesRepository {
  const SupabasePermissionOverridesRepository();

  static const String table = 'member_permission_overrides';

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _tenantOnline() async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw const PermissionsOfflineException();
    }
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }
    return tenantId;
  }

  @override
  Future<PermissionOverrides?> fetchMine() async {
    try {
      final tenantId = SyncContext.tenantId;
      final userId = SyncContext.userId;
      if (tenantId == null || userId == null) return null;
      final rows = await _client
          .from(table)
          .select('permission,effect')
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 8));
      return parseOverrideRows([
        for (final r in rows) Map<String, dynamic>.from(r as Map),
      ]);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PermissionOverrides> fetchFor(String userId) async {
    final tenantId = await _tenantOnline();
    final rows = await _client
        .from(table)
        .select('permission,effect')
        .eq('tenant_id', tenantId)
        .eq('user_id', userId);
    return parseOverrideRows([
      for (final r in rows) Map<String, dynamic>.from(r as Map),
    ]);
  }

  @override
  Future<void> setOverride({
    required String userId,
    required Permission permission,
    required PermissionEffect? effect,
  }) async {
    final tenantId = await _tenantOnline();
    if (effect == null) {
      await _client
          .from(table)
          .delete()
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .eq('permission', permission.key);
      return;
    }
    await _client.from(table).upsert({
      'tenant_id': tenantId,
      'user_id': userId,
      'permission': permission.key,
      'effect': effect.wire,
      'updated_by': SyncContext.userId,
    }, onConflict: 'tenant_id,user_id,permission');
  }

  @override
  Future<void> resetAll(String userId) async {
    final tenantId = await _tenantOnline();
    await _client
        .from(table)
        .delete()
        .eq('tenant_id', tenantId)
        .eq('user_id', userId);
  }
}

final permissionOverridesRepositoryProvider =
    Provider<PermissionOverridesRepository>(
  (ref) => const SupabasePermissionOverridesRepository(),
);

/// Where the signed-in user's own overrides are cached for offline use. An
/// interface so tests can supply an in-memory fake (Hive hangs on the widget
/// test clock).
abstract class PermissionOverridesCache {
  PermissionOverrides load(String scope);
  Future<void> save(String scope, PermissionOverrides overrides);
}

class HivePermissionOverridesCache implements PermissionOverridesCache {
  const HivePermissionOverridesCache();

  @override
  PermissionOverrides load(String scope) => decodeOverrides(
      AppPreferencesService.instance.permissionOverridesCache(scope));

  @override
  Future<void> save(String scope, PermissionOverrides overrides) =>
      AppPreferencesService.instance
          .setPermissionOverridesCache(scope, encodeOverrides(overrides));
}

final permissionOverridesCacheProvider = Provider<PermissionOverridesCache>(
  (ref) => const HivePermissionOverridesCache(),
);
