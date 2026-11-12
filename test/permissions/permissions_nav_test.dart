import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/admin/domain/division.dart';
import 'package:voltcore/modules/admin/domain/entities/admin_dashboard_stats_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/infra/division_repository.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository_impl.dart';
import 'package:voltcore/modules/admin/presenter/pages/technicians_page.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class _Admin extends Fake implements AdminRepository {
  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async => const [
        TenantMemberEntity(
          tenantId: 't1',
          userId: 'u7',
          displayName: 'Tom Technician',
          email: 'tom@example.com',
          role: UserRole.tech,
          isActive: true,
        ),
      ];

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() =>
      throw UnimplementedError();
}

class _Divisions implements DivisionRepository {
  @override
  Future<List<Division>> list() async => const [];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  testWidgets('each member row opens that member permissions route',
      (t) async {
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const TechniciansPage()),
      GoRoute(
        path: RoutePaths.adminPermissions,
        name: RouteNames.adminPermissions,
        builder: (_, s) =>
            Scaffold(body: Text('permissions for ${s.pathParameters['userId']}')),
      ),
    ]);
    addTearDown(router.dispose);

    await t.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) {
          final c = AuthController(ref, _FakeLogin(), _FakeLogout());
          c.state = const AuthState(
            isAuthenticated: true,
            currentRole: UserRole.admin,
            userId: 'admin1',
            grantedRoles: {UserRole.admin},
          );
          return c;
        }),
        adminRepositoryProvider.overrideWithValue(_Admin()),
        divisionRepositoryProvider.overrideWithValue(_Divisions()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }

    await t.tap(find.byKey(const Key('permissions_button_u7')));
    await t.pumpAndSettle();
    expect(find.text('permissions for u7'), findsOneWidget);
  });

  test('the permissions route is registered, default-deny and admin only', () {
    expect(RouteRoles.configuredRouteNames, contains(RouteNames.adminPermissions));
    for (final role in UserRole.values) {
      expect(
        RouteRoles.isAllowedByName(
            name: RouteNames.adminPermissions, role: role),
        role == UserRole.admin,
        reason: role.name,
      );
    }
    expect(RouteRoles.isAllowedByName(
        name: RouteNames.adminPermissions, role: null), isFalse);
  });
}
