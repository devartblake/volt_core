import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/presenter/sign_off_access.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/dashboard/presenter/analytics_providers.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/inspections/presenter/controllers/inspection_list_prefs.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/permissions/domain/permission.dart';
import 'package:voltcore/modules/permissions/infra/permission_overrides_repository.dart';
import 'package:voltcore/modules/permissions/presenter/permission_providers.dart';
import 'package:voltcore/modules/schedule/presenter/controllers/schedule_assignment.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class FakeOverridesRepo implements PermissionOverridesRepository {
  FakeOverridesRepo({this.mine, Map<String, PermissionOverrides>? byUser})
      : byUser = byUser ?? {};

  /// What [fetchMine] answers; null simulates offline / unreadable.
  PermissionOverrides? mine;
  final Map<String, PermissionOverrides> byUser;
  bool offline = false;
  final writes = <String>[];

  @override
  Future<PermissionOverrides?> fetchMine() async => mine;

  @override
  Future<PermissionOverrides> fetchFor(String userId) async {
    if (offline) throw const PermissionsOfflineException();
    return {...?byUser[userId]};
  }

  @override
  Future<void> setOverride({
    required String userId,
    required Permission permission,
    required PermissionEffect? effect,
  }) async {
    if (offline) throw const PermissionsOfflineException();
    writes.add('$userId:${permission.key}:${effect?.wire ?? 'reset'}');
    final m = byUser.putIfAbsent(userId, () => {});
    if (effect == null) {
      m.remove(permission);
    } else {
      m[permission] = effect;
    }
  }

  @override
  Future<void> resetAll(String userId) async {
    if (offline) throw const PermissionsOfflineException();
    writes.add('$userId:reset_all');
    byUser[userId] = {};
  }
}

class FakeCache implements PermissionOverridesCache {
  final store = <String, PermissionOverrides>{};

  @override
  PermissionOverrides load(String scope) => store[scope] ?? const {};

  @override
  Future<void> save(String scope, PermissionOverrides overrides) async {
    store[scope] = overrides;
  }
}

ProviderContainer containerFor(
  UserRole? role, {
  FakeOverridesRepo? repo,
  FakeCache? cache,
  String userId = 'u1',
}) {
  final c = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) {
      final ctl = AuthController(ref, _FakeLogin(), _FakeLogout());
      ctl.state = AuthState(
        isAuthenticated: role != null,
        currentRole: role,
        userId: role == null ? null : userId,
        displayName: 'Test',
        grantedRoles: {if (role != null) role},
      );
      return ctl;
    }),
    permissionOverridesRepositoryProvider
        .overrideWithValue(repo ?? FakeOverridesRepo()),
    permissionOverridesCacheProvider.overrideWithValue(cache ?? FakeCache()),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// What the app did BEFORE per-user overrides existed, written out per role so
/// a mistake in the catalogue shows up as a failing row.
bool _oldBehaviour(Permission p, UserRole r) {
  final admin = r == UserRole.admin;
  final sup = r == UserRole.supervisor;
  final disp = r == UserRole.dispatcher;
  return switch (p) {
    Permission.signOffWork => r != UserRole.apprentice,
    Permission.deleteRecords => r != UserRole.apprentice,
    Permission.deleteInspections => admin || disp,
    Permission.assignSchedule => !r.isFieldWorker,
    Permission.manageCustomers => admin || sup || disp,
    Permission.editPartsProfiles => admin || sup || disp,
    Permission.manageInventory => admin,
    Permission.reserveStock => admin || sup || disp,
    Permission.manageFleet => admin || sup || disp,
    Permission.manageToolCatalog => admin,
    Permission.scheduleReadiness => admin || sup || disp,
    Permission.viewWorkloadAnalytics => admin || disp,
    Permission.viewInventoryAnalytics => admin || sup || disp,
  };
}

void main() {
  group('catalogue', () {
    test('role defaults equal the behaviour before overrides, for every role',
        () {
      for (final p in Permission.values) {
        for (final r in UserRole.values) {
          expect(p.defaultFor(r), _oldBehaviour(p, r),
              reason: '${p.key} for ${r.name}');
          expect(resolvePermission(r, p, const {}), _oldBehaviour(p, r),
              reason: 'no override: ${p.key} for ${r.name}');
        }
        expect(p.defaultFor(null), isFalse);
      }
    });

    test('apprentice defaults: no sign off or delete, otherwise like a tech',
        () {
      for (final p in Permission.values) {
        if (p == Permission.signOffWork || p == Permission.deleteRecords) {
          expect(p.defaultFor(UserRole.apprentice), isFalse);
        } else {
          expect(p.defaultFor(UserRole.apprentice), p.defaultFor(UserRole.tech),
              reason: p.key);
        }
      }
    });

    test('keys are unique, stable, database-safe and fully described', () {
      final keys = Permission.values.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final p in Permission.values) {
        // Mirrors the CHECK on member_permission_overrides.permission.
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(p.key), isTrue);
        expect(p.key.length, lessThanOrEqualTo(64));
        expect(p.label.trim(), isNotEmpty);
        expect(p.description.trim(), isNotEmpty);
        expect(Permission.fromKey(p.key), p);
        expect(Permission.inGroup(p.group), contains(p));
      }
      expect(Permission.fromKey('nope'), isNull);
      expect(Permission.fromKey(null), isNull);
    });

    test('stable keys that are stored in the database', () {
      expect(Permission.signOffWork.key, 'sign_off_work');
      expect(Permission.deleteRecords.key, 'delete_records');
      expect(Permission.manageInventory.key, 'manage_inventory');
      expect(Permission.assignSchedule.key, 'assign_schedule');
    });

    test('admin-only functions are not overridable', () {
      const forbidden = [
        'manage_users',
        'manage_team',
        'manage_roles',
        'manage_permissions',
        'manage_divisions',
        'view_audit_log',
        'admin_settings',
        'invite_users',
        'edit_readiness_config',
      ];
      for (final k in forbidden) {
        expect(Permission.fromKey(k), isNull, reason: k);
      }
    });

    test('overrides never change route access', () {
      // Route access is role based; the catalogue has no hook into it.
      expect(RouteRoles.rolesFor(RouteNames.adminPermissions), {UserRole.admin});
      expect(RouteRoles.rolesFor(RouteNames.adminTechnicians), {UserRole.admin});
      expect(RouteRoles.rolesFor(RouteNames.adminAudit), {UserRole.admin});
      expect(RoutePaths.adminPermissionsFor('abc'),
          '/admin/technicians/abc/permissions');
    });
  });

  group('resolvePermission', () {
    test('allow grants, deny revokes, nothing means the role default', () {
      const p = Permission.manageInventory;
      expect(resolvePermission(UserRole.tech, p, const {}), isFalse);
      expect(
          resolvePermission(
              UserRole.tech, p, {p: PermissionEffect.allow}),
          isTrue);
      expect(resolvePermission(UserRole.admin, p, const {}), isTrue);
      expect(
          resolvePermission(
              UserRole.admin, p, {p: PermissionEffect.deny}),
          isFalse);
      // An override of another permission changes nothing here.
      expect(
          resolvePermission(UserRole.tech, p,
              {Permission.signOffWork: PermissionEffect.allow}),
          isFalse);
    });

    test('a signed-out session gets nothing, even with an allow', () {
      for (final p in Permission.values) {
        expect(resolvePermission(null, p, {p: PermissionEffect.allow}), isFalse);
      }
    });

    test('parse and cache round-trip ignore unknown permissions and effects',
        () {
      final parsed = parseOverrideRows([
        {'permission': 'sign_off_work', 'effect': 'allow'},
        {'permission': 'manage_fleet', 'effect': 'deny'},
        {'permission': 'from_the_future', 'effect': 'allow'},
        {'permission': 'delete_records', 'effect': 'maybe'},
        {'permission': null, 'effect': 'allow'},
      ]);
      expect(parsed, {
        Permission.signOffWork: PermissionEffect.allow,
        Permission.manageFleet: PermissionEffect.deny,
      });
      final encoded = encodeOverrides(parsed);
      expect(encoded, {'sign_off_work': 'allow', 'manage_fleet': 'deny'});
      expect(decodeOverrides(encoded), parsed);
      expect(decodeOverrides(null), isEmpty);
      expect(decodeOverrides('junk'), isEmpty);
    });
  });

  group('providers', () {
    test('with no overrides every gate follows the role', () {
      for (final r in UserRole.values) {
        final c = containerFor(r);
        expect(c.read(canSignOffProvider), _oldBehaviour(Permission.signOffWork, r));
        expect(c.read(canDeleteRecordsProvider),
            _oldBehaviour(Permission.deleteRecords, r));
        expect(c.read(inspectionCanDeleteProvider),
            _oldBehaviour(Permission.deleteInspections, r));
        expect(c.read(canAssignScheduleProvider),
            _oldBehaviour(Permission.assignSchedule, r));
        expect(c.read(canManageInventoryProvider),
            _oldBehaviour(Permission.manageInventory, r));
        expect(c.read(canReserveStockProvider),
            _oldBehaviour(Permission.reserveStock, r));
        expect(c.read(fleetManagerProvider),
            _oldBehaviour(Permission.manageFleet, r));
        expect(c.read(fleetCatalogEditorProvider),
            _oldBehaviour(Permission.manageToolCatalog, r));
        final analytics = c.read(analyticsAccessProvider);
        expect(analytics.workload,
            _oldBehaviour(Permission.viewWorkloadAnalytics, r));
        expect(analytics.inventory,
            _oldBehaviour(Permission.viewInventoryAnalytics, r));
      }
    });

    test('signed out: sign off and delete stay true (the router refuses them)',
        () {
      final c = containerFor(null);
      expect(c.read(canSignOffProvider), isTrue);
      expect(c.read(canDeleteRecordsProvider), isTrue);
      expect(c.read(canManageInventoryProvider), isFalse);
    });

    test('apprentice is blocked by default and unblocked by an Allow override',
        () async {
      final repo = FakeOverridesRepo();
      final c = containerFor(UserRole.apprentice, repo: repo);
      expect(c.read(canSignOffProvider), isFalse);
      expect(c.read(canDeleteRecordsProvider), isFalse);

      repo.mine = {Permission.signOffWork: PermissionEffect.allow};
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canSignOffProvider), isTrue);
      // Only the permission that was allowed.
      expect(c.read(canDeleteRecordsProvider), isFalse);
    });

    test('a Deny override takes a permission away from a technician', () async {
      final repo = FakeOverridesRepo(
          mine: {Permission.signOffWork: PermissionEffect.deny});
      final c = containerFor(UserRole.tech, repo: repo);
      expect(c.read(canSignOffProvider), isTrue); // before the fetch finishes
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canSignOffProvider), isFalse);
      expect(c.read(canDeleteRecordsProvider), isTrue);
    });

    test('Allow gives an inventory gate to a technician, Deny removes it from an admin',
        () async {
      var repo = FakeOverridesRepo(
          mine: {Permission.manageInventory: PermissionEffect.allow});
      var c = containerFor(UserRole.tech, repo: repo);
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canManageInventoryProvider), isTrue);

      repo = FakeOverridesRepo(
          mine: {Permission.manageInventory: PermissionEffect.deny});
      c = containerFor(UserRole.admin, repo: repo);
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canManageInventoryProvider), isFalse);
      // The admin is not locked out of anything else.
      expect(c.read(canSignOffProvider), isTrue);
      expect(RouteRoles.isAllowedByName(
          name: RouteNames.adminPermissions, role: UserRole.admin), isTrue);
    });

    test('works offline from the cache, and a good fetch updates the cache',
        () async {
      final cache = FakeCache();
      // userId u1, tenant not configured in tests -> scope "none:u1".
      cache.store['none:u1'] = {Permission.signOffWork: PermissionEffect.allow};
      final repo = FakeOverridesRepo(); // mine == null: offline / unreadable
      final c = containerFor(UserRole.apprentice, repo: repo, cache: cache);
      expect(c.read(canSignOffProvider), isTrue);
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canSignOffProvider), isTrue, reason: 'cache kept');

      repo.mine = const {};
      await c.read(permissionOverridesProvider.notifier).refresh();
      expect(c.read(canSignOffProvider), isFalse);
      expect(cache.store['none:u1'], isEmpty);
    });

    test('overrides belong to the user: a different user starts clean', () {
      final cache = FakeCache()
        ..store['none:u1'] = {Permission.signOffWork: PermissionEffect.allow};
      final c = containerFor(UserRole.apprentice, cache: cache, userId: 'u2');
      expect(c.read(canSignOffProvider), isFalse);
    });
  });
}
