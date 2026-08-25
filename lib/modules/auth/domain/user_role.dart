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

/// Highest-privilege role in [roles], or null when the set is empty.
///
/// Used when a user holds several grants (e.g. admin in one tenant, tech in
/// another) and the session has to act as one of them.
UserRole? highestRole(Iterable<UserRole> roles) {
  UserRole? best;
  for (final role in roles) {
    if (best == null || role.privilege > best.privilege) best = role;
  }
  return best;
}

/// Convenience extension with helpers for display and parsing.
extension UserRoleX on UserRole {
  /// Relative privilege, used only to pick a default among granted roles.
  /// Higher means more privileged. Not a substitute for per-route RBAC.
  int get privilege {
    switch (this) {
      case UserRole.tech:
        return 0;
      case UserRole.dispatcher:
        return 1;
      case UserRole.supervisor:
        return 2;
      case UserRole.admin:
        return 3;
    }
  }

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

  /// The value Postgres expects for a `public.app_role` column.
  ///
  /// **Not** the same as [name]. The Dart enum spells the field role `tech`
  /// while the database enum is `('admin','supervisor','dispatcher',
  /// 'technician')`, so writing `role.name` to `tenant_members.role` or
  /// `tenant_role_assignments.{previous,new}_role` fails with
  /// `22P02 invalid input value for enum app_role: "tech"`.
  ///
  /// Reading is unaffected — [fromString] already accepts `technician`.
  ///
  /// Only for columns typed `app_role`. The legacy `technicians.role` is plain
  /// text defaulting to `'tech'`, and keeps using [name].
  String get wire {
    switch (this) {
      case UserRole.tech:
        return 'technician';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.dispatcher:
        return 'dispatcher';
      case UserRole.admin:
        return 'admin';
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
