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

  static bool isAllowed({
    required String path,
    required UserRole? role,
  }) {
    final allowed = pathRoles[path];
    if (allowed == null) {
      // No restriction defined → treat as open to authenticated users
      return true;
    }
    if (role == null) {
      return false;
    }
    return allowed.contains(role);
  }
}