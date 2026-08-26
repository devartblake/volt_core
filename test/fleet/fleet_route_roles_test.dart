import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

/// The fleet's access rule, stated once.
///
/// A technician is stationed to one vehicle: they are responsible for it and
/// its assets and they sign for it when it is dispatched, so they can open the
/// list and the detail page. Editing the fleet record stays with dispatch.
///
/// `route_roles_test.dart` already fails if a RouteNames constant is missing
/// from the map entirely. This asserts the specific split, which completeness
/// cannot: granting tech `fleet_vehicle_edit` by accident would pass that test
/// and hand a driver the ability to reassign their own van.
void main() {
  bool allows(String route, UserRole role) =>
      RouteRoles.isAllowedByName(name: route, role: role);

  const readable = ['fleet', 'fleet_vehicle_detail'];
  const managerOnly = ['fleet_vehicle_new', 'fleet_vehicle_edit'];

  group('a technician', () {
    test('can open their vehicle', () {
      for (final route in readable) {
        expect(allows(route, UserRole.tech), isTrue, reason: route);
      }
    });

    test('cannot add or edit a vehicle', () {
      for (final route in managerOnly) {
        expect(allows(route, UserRole.tech), isFalse, reason: route);
      }
    });
  });

  group('managers', () {
    test('can reach every fleet route', () {
      const managers = [
        UserRole.supervisor,
        UserRole.dispatcher,
        UserRole.admin,
      ];
      for (final role in managers) {
        for (final route in [...readable, ...managerOnly]) {
          expect(allows(route, role), isTrue, reason: '$role → $route');
        }
      }
    });
  });

  test('the write split matches can_manage_tenant_work()', () {
    // The migration gates fleet_vehicles' insert/update/delete policies on
    // can_manage_tenant_work(), which is admin/supervisor/dispatcher. If this
    // map and that function disagree, a role gets a screen it cannot save
    // from — the failure mode that made Team & Roles look broken.
    const canManage = {UserRole.admin, UserRole.supervisor, UserRole.dispatcher};

    for (final role in UserRole.values) {
      for (final route in managerOnly) {
        expect(
          allows(route, role),
          canManage.contains(role),
          reason: '$role → $route',
        );
      }
    }
  });
}
