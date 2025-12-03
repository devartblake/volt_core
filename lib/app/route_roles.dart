import '../modules/auth/auth_state.dart';

/// Which roles can access which route (by *path* or *name*).
///
/// Use *path* keys for the redirect controllers in GoRouter, and use
/// *routeName* keys if you want additional checks elsewhere.
class RouteRoles {
  /// Map of paths → allowed roles.
  static const Map<String, List<UserRole>> pathRoles = {
    // Public
    '/login': [],
    '/403': [],

    // Dashboard: any logged-in user
    '/': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],

    // Inspections
    '/inspections': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
    '/inspections/new': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
    '/inspections/pending': [
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],

    // Maintenance
    '/maintenance': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
    '/maintenance/new': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
    '/maintenance/archive': [
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],

    // Schedule
    '/schedule': [
      UserRole.dispatcher,
      UserRole.supervisor,
      UserRole.admin,
    ],

    // Equipment
    '/nameplate-list': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
    '/equipment/search': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],

    // System / Settings – lock down to admin for now
    '/selection-management': [UserRole.admin],
    '/settings': [UserRole.admin],
    '/about': [
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    ],
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