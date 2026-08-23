import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

/// Navigation entries the drawer offers, mirrored from `_navSections` /
/// `_quickActions` in app_drawer.dart. Keep in sync when adding drawer items —
/// these tests assert the *policy* each entry lands under.
const _drawerRouteNames = <String>{
  RouteNames.dashboard,
  RouteNames.analytics,
  RouteNames.inspections,
  RouteNames.inspectionNew,
  RouteNames.inspectionsPending,
  RouteNames.maintenance,
  RouteNames.schedule,
  RouteNames.maintenanceNew,
  RouteNames.maintenanceArchive,
  RouteNames.workOrders,
  RouteNames.workOrderNew,
  RouteNames.nameplateList,
  RouteNames.customerSites,
  RouteNames.documents,
  RouteNames.selectionManagement,
  RouteNames.settings,
  RouteNames.about,
  RouteNames.adminDashboard,
  RouteNames.adminTechnicians,
  RouteNames.tenantsSettings,
  RouteNames.adminSettings,
};

Set<String> _visibleTo(UserRole role) => _drawerRouteNames
    .where((n) => RouteRoles.isAllowedByName(name: n, role: role))
    .toSet();

void main() {
  group('role-aware navigation', () {
    test('every drawer entry has an RBAC decision', () {
      for (final name in _drawerRouteNames) {
        expect(
          RouteRoles.rolesFor(name),
          isNotEmpty,
          reason: 'Drawer offers "$name" but RouteRoles has no entry, so the '
              'default-deny filter would hide it from everyone.',
        );
      }
    });

    test('technicians see no administration entries', () {
      final visible = _visibleTo(UserRole.tech);

      expect(visible, isNot(contains(RouteNames.adminDashboard)));
      expect(visible, isNot(contains(RouteNames.adminTechnicians)));
      expect(visible, isNot(contains(RouteNames.adminSettings)));
      expect(visible, isNot(contains(RouteNames.tenantsSettings)));
    });

    test('technicians keep their day-to-day entries', () {
      final visible = _visibleTo(UserRole.tech);

      expect(
        visible,
        containsAll([
          RouteNames.dashboard,
          RouteNames.inspections,
          RouteNames.inspectionNew,
          RouteNames.maintenance,
          RouteNames.schedule,
          RouteNames.documents,
          RouteNames.settings,
        ]),
      );
    });

    test('supervisors get review entries but not administration', () {
      final visible = _visibleTo(UserRole.supervisor);

      expect(
        visible,
        containsAll([
          RouteNames.inspectionsPending,
          RouteNames.maintenanceArchive,
          RouteNames.selectionManagement,
        ]),
      );
      expect(visible, isNot(contains(RouteNames.adminDashboard)));
    });

    test('admins see the full administration group', () {
      final visible = _visibleTo(UserRole.admin);

      expect(
        visible,
        containsAll([
          RouteNames.adminDashboard,
          RouteNames.adminTechnicians,
          RouteNames.tenantsSettings,
          RouteNames.adminSettings,
        ]),
      );
    });

    test('the administration group is entirely admin-only', () {
      // Every item in the drawer's Administration section, so the whole
      // section collapses for other roles instead of showing an empty heading.
      const administration = [
        RouteNames.adminDashboard,
        RouteNames.adminTechnicians,
        RouteNames.tenantsSettings,
        RouteNames.adminSettings,
      ];

      for (final name in administration) {
        expect(RouteRoles.rolesFor(name), {UserRole.admin}, reason: name);
      }
    });

    test('admin can reach everything a technician can', () {
      final tech = _visibleTo(UserRole.tech);
      final admin = _visibleTo(UserRole.admin);

      // A privilege switch should never lose access to ordinary screens.
      expect(admin.containsAll(tech), isTrue,
          reason: 'admin is missing: ${tech.difference(admin)}');
    });
  });
}
