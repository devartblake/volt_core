/// Core user roles used across the app for RBAC.
///
/// This enum is the single source of truth for:
/// - Authentication state (`AuthState.currentRole`)
/// - Route access control (`kRouteRoles` in route_roles.dart)
/// - Role-aware navigation (`AppDrawer`)
/// - Guards (`RoleGuard`, router redirect)
///
/// NOTE:
/// If you ever add/remove roles, also update:
/// - kRouteRoles in route_roles.dart
/// - Any UI that shows role labels / dropdowns (e.g. LoginPage)
enum UserRole {
  tech,
  supervisor,
  dispatcher,
  admin,
}

/// Convenience extension with helpers for display and parsing.
extension UserRoleX on UserRole {
  /// Human-friendly label for UI.
  String get label {
    switch (this) {
      case UserRole.tech:
        return 'Technician';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.dispatcher:
        return 'Dispatcher';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Short machine-safe code (useful for persistence or logs).
  ///
  /// Example string values:
  /// - tech
  /// - supervisor
  /// - dispatcher
  /// - admin
  String get code => name; // uses the enum's built-in name

  /// Simple convenience flags
  bool get isTech => this == UserRole.tech;
  bool get isSupervisor => this == UserRole.supervisor;
  bool get isDispatcher => this == UserRole.dispatcher;
  bool get isAdmin => this == UserRole.admin;

  /// Parse from a string (e.g. from Hive / Supabase).
  ///
  /// Accepts either:
  /// - the enum name: "tech", "supervisor", "dispatcher", "admin"
  /// - the label: "Technician", "Supervisor", "Dispatcher", "Admin"
  ///
  /// Returns `null` if the value is unknown.
  static UserRole? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = raw.trim().toLowerCase();

    switch (value) {
      case 'tech':
      case 'technician':
        return UserRole.tech;
      case 'supervisor':
        return UserRole.supervisor;
      case 'dispatcher':
        return UserRole.dispatcher;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      default:
        return null;
    }
  }
}
