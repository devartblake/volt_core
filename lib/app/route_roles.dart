import '../modules/auth/domain/user_role.dart';

/// Defines which roles are allowed to access each named route.
///
/// Keys must match the `name:` values in your GoRouter routes
/// (`RouteNames` in `core/constants/route_paths.dart`).
///
/// **This map is default-deny.** A route that isn't listed here is refused for
/// every role, so forgetting an entry fails closed (→ `/403`) instead of
/// silently exposing a screen. Routes that must be reachable without a role are
/// listed in [_publicRouteNames]. `test/app/route_roles_test.dart` fails if any
/// `RouteNames` constant is missing from both.
class RouteRoles {
  /// Routes reachable without an authenticated role (the auth flow itself).
  static const Set<String> _publicRouteNames = {
    'login',
    'forbidden',
  };

  static const Map<String, Set<UserRole>> _rolesByRouteName = {
    // ----- Core shell / dashboards -----
    'dashboard': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    // "My Workload" — personal inspection/maintenance counts. Every role has
    // their own workload, and the dashboard offers the tile to all of them, so
    // restricting the route to techs only sent everyone else to /403.
    'tech_dashboard': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'analytics': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'admin_dashboard': {UserRole.admin},
    'admin_settings': {UserRole.admin},
    // Technician management edits other users' roles — admin only.
    'admin_technicians': {UserRole.admin},

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
    'schedule_task': {
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
    'equipment_history': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Documents -----
    'documents': {
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
    // Tenant configuration affects every user in the tenant — admin only.
    'tenants_settings': {UserRole.admin},

    // ----- Debug tooling -----
    // Only registered in debug builds (see app_router.dart), and restricted to
    // admins even there: these expose the raw local database and request log.
    'debug_menu': {UserRole.admin},
    'hive_debug': {UserRole.admin},
    'network_debug': {UserRole.admin},
  };

  /// Returns true if this [role] may open the route named [name].
  ///
  /// Fails closed: an unnamed route, an unknown route name, or a route with an
  /// empty role set is **denied**. Only [_publicRouteNames] bypass the check.
  static bool isAllowedByName({
    required String? name,
    required UserRole? role,
  }) {
    if (name != null && _publicRouteNames.contains(name)) return true;

    // Anything else needs both a resolvable route name and a role.
    if (name == null || role == null) return false;

    final allowed = _rolesByRouteName[name];
    if (allowed == null || allowed.isEmpty) return false;

    return allowed.contains(role);
  }

  /// Route names carrying an explicit role set. Exposed for tests and for
  /// role-aware navigation filtering.
  static Set<String> get configuredRouteNames => _rolesByRouteName.keys.toSet();

  /// Route names reachable without a role (auth flow).
  static Set<String> get publicRouteNames => _publicRouteNames;

  /// Roles permitted on [name], or an empty set when the route is unknown.
  static Set<UserRole> rolesFor(String name) =>
      _rolesByRouteName[name] ?? const {};
}
