import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

/// Every route name the app can navigate to by name.
const _allRouteNames = <String>{
  RouteNames.login,
  RouteNames.forbidden,
  RouteNames.dashboard,
  RouteNames.techDashboard,
  RouteNames.analytics,
  RouteNames.inspections,
  RouteNames.inspectionNew,
  RouteNames.inspectionEdit,
  RouteNames.inspectionDetail,
  RouteNames.inspectionsPending,
  RouteNames.maintenance,
  RouteNames.maintenanceNew,
  RouteNames.maintenanceDetail,
  RouteNames.maintenanceArchive,
  RouteNames.workOrders,
  RouteNames.workOrderNew,
  RouteNames.workOrderEdit,
  RouteNames.templates,
  RouteNames.templateResponse,
  RouteNames.schedule,
  RouteNames.scheduleTask,
  RouteNames.scheduleTaskDetail,
  RouteNames.nameplateList,
  RouteNames.nameplateIntervals,
  RouteNames.equipmentSearch,
  RouteNames.equipmentHistory,
  RouteNames.fleet,
  RouteNames.fleetNew,
  RouteNames.fleetEdit,
  RouteNames.fleetDetail,
  RouteNames.customerSites,
  RouteNames.documents,
  RouteNames.selectionManagement,
  RouteNames.settings,
  RouteNames.about,
  RouteNames.tenantsSettings,
  RouteNames.adminDashboard,
  RouteNames.adminSettings,
  RouteNames.adminTechnicians,
  'debug_menu',
  'hive_debug',
  'network_debug',
};

void main() {
  group('RouteRoles coverage', () {
    test('every route name has an explicit RBAC decision', () {
      final configured = RouteRoles.configuredRouteNames;
      final public = RouteRoles.publicRouteNames;

      final undecided = _allRouteNames
          .where((n) => !configured.contains(n) && !public.contains(n))
          .toList()
        ..sort();

      expect(
        undecided,
        isEmpty,
        reason: 'These routes have no RouteRoles entry and are default-denied. '
            'Add them to _rolesByRouteName (or _publicRouteNames): $undecided',
      );
    });

    test('no RBAC entry references an unknown route name', () {
      final unknown = RouteRoles.configuredRouteNames
          .where((n) => !_allRouteNames.contains(n))
          .toList()
        ..sort();

      expect(
        unknown,
        isEmpty,
        reason: 'RouteRoles references route names that no longer exist: '
            '$unknown',
      );
    });

    test('no route is configured with an empty role set', () {
      for (final name in RouteRoles.configuredRouteNames) {
        expect(
          RouteRoles.rolesFor(name),
          isNotEmpty,
          reason: '"$name" has an empty role set, which denies everyone.',
        );
      }
    });
  });

  group('RouteRoles enforcement', () {
    test('unknown route names are denied for every role (fail closed)', () {
      for (final role in UserRole.values) {
        expect(
          RouteRoles.isAllowedByName(
            name: 'route_that_does_not_exist',
            role: role,
          ),
          isFalse,
        );
      }
    });

    test('a null route name or missing role is denied', () {
      expect(
        RouteRoles.isAllowedByName(name: null, role: UserRole.admin),
        isFalse,
      );
      expect(
        RouteRoles.isAllowedByName(name: RouteNames.dashboard, role: null),
        isFalse,
      );
    });

    test('public routes are reachable without a role', () {
      expect(
        RouteRoles.isAllowedByName(name: RouteNames.login, role: null),
        isTrue,
      );
      expect(
        RouteRoles.isAllowedByName(name: RouteNames.forbidden, role: null),
        isTrue,
      );
    });

    test('admin-only routes reject non-admin roles', () {
      const adminOnly = [
        RouteNames.adminDashboard,
        RouteNames.adminSettings,
        RouteNames.adminTechnicians,
        RouteNames.tenantsSettings,
        'debug_menu',
        'hive_debug',
        'network_debug',
      ];

      for (final name in adminOnly) {
        expect(
          RouteRoles.isAllowedByName(name: name, role: UserRole.admin),
          isTrue,
        );
        for (final role in [
          UserRole.tech,
          UserRole.supervisor,
          UserRole.dispatcher,
        ]) {
          expect(
            RouteRoles.isAllowedByName(name: name, role: role),
            isFalse,
          );
        }
      }
    });

    test('template management rejects technicians and permits managers', () {
      expect(
        RouteRoles.isAllowedByName(
          name: RouteNames.templates,
          role: UserRole.tech,
        ),
        isFalse,
      );
      for (final role in [
        UserRole.supervisor,
        UserRole.dispatcher,
        UserRole.admin,
      ]) {
        expect(
          RouteRoles.isAllowedByName(name: RouteNames.templates, role: role),
          isTrue,
        );
      }
    });

    test('template field execution is available to every operational role', () {
      for (final role in UserRole.values) {
        expect(
          RouteRoles.isAllowedByName(
            name: RouteNames.templateResponse,
            role: role,
          ),
          isTrue,
          reason: '$role should be allowed to execute published field forms',
        );
      }
    });

    test('the workload dashboard is reachable by every role', () {
      for (final role in UserRole.values) {
        expect(
          RouteRoles.isAllowedByName(
            name: RouteNames.techDashboard,
            role: role,
          ),
          isTrue,
        );
      }
    });

    test('technicians keep access to their day-to-day routes', () {
      const techRoutes = [
        RouteNames.dashboard,
        RouteNames.techDashboard,
        RouteNames.inspections,
        RouteNames.inspectionNew,
        RouteNames.inspectionDetail,
        RouteNames.maintenance,
        RouteNames.maintenanceNew,
        RouteNames.workOrders,
        RouteNames.workOrderNew,
        RouteNames.workOrderEdit,
        RouteNames.templateResponse,
        RouteNames.schedule,
        RouteNames.scheduleTask,
        RouteNames.scheduleTaskDetail,
        RouteNames.documents,
        RouteNames.settings,
      ];

      for (final name in techRoutes) {
        expect(
          RouteRoles.isAllowedByName(name: name, role: UserRole.tech),
          isTrue,
          reason: 'tech should reach $name',
        );
      }
    });

    test('supervisor-only review routes reject technicians', () {
      for (final name in [
        RouteNames.inspectionsPending,
        RouteNames.maintenanceArchive,
        RouteNames.selectionManagement,
      ]) {
        expect(
          RouteRoles.isAllowedByName(name: name, role: UserRole.tech),
          isFalse,
        );
        expect(
          RouteRoles.isAllowedByName(name: name, role: UserRole.supervisor),
          isTrue,
        );
      }
    });
  });
}
