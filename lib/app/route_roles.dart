import '../modules/auth/domain/user_role.dart';
import '../modules/auth/state/auth_state.dart';

/// Defines which roles are allowed to access each named route.
///
/// Keys must match the `name:` values in your GoRouter routes.
class RouteRoles {
  static const Map<String, Set<UserRole>> _rolesByRouteName = {
    // ----- Core shell / dashboards -----
    'dashboard': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'tech_dashboard': {UserRole.tech},
    'admin_dashboard': {UserRole.admin},
    'admin_settings': {UserRole.admin},

    // ----- Inspections -----
    'inspections': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'inspection_new': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'inspection_detail': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'inspections_pending': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Maintenance -----
    'maintenance': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'maintenance_new': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'maintenance_detail': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'maintenance_archive': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Schedule -----
    'schedule': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Equipment / Nameplate -----
    'nameplate_list': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'nameplate_intervals': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'equipment_search': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Settings / System -----
    'selection_management': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'settings': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'about': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
  };

  /// Returns true if this [role] is allowed on the given route [name].
  ///
  /// If there is no entry for [name], the route is treated as "public"
  /// from an RBAC perspective (only login / 403 / notFound etc).
  static bool isAllowedByName({
    required String? name,
    required UserRole? role,
  }) {
    // Public / unnamed route: treated as allowed (login, 403, etc).
    if (name == null || role == null) return true;

    final allowed = _rolesByRouteName[name];
    if (allowed == null || allowed.isEmpty) {
      // If we haven't configured it, treat as allowed for all roles.
      return true;
    }

    return allowed.contains(role);
  }
}