import '../../auth/domain/user_role.dart';

/// Section headings on the admin permissions screen.
enum PermissionGroup {
  fieldWork('Field work'),
  scheduleAndCustomers('Schedule and customers'),
  inventory('Inventory'),
  fleet('Fleet'),
  analytics('Analytics and readiness');

  const PermissionGroup(this.label);
  final String label;
}

/// What an admin can set for one person and one permission.
enum PermissionEffect {
  allow('allow'),
  deny('deny');

  const PermissionEffect(this.wire);

  /// The value stored in `member_permission_overrides.effect`.
  final String wire;

  static PermissionEffect? fromWire(Object? raw) {
    for (final e in values) {
      if (e.wire == raw) return e;
    }
    return null;
  }
}

/// The fixed catalogue of named permissions an admin can override per person.
///
/// Only gates that already exist in the app AND can safely be flipped for one
/// person are listed. Each has a role default table that reproduces the
/// behaviour the app had before overrides existed, so with no override rows
/// nothing changes.
///
/// NOT in the catalogue on purpose (always decided by role, admin only):
/// managing users, roles, divisions and permissions, the audit log, admin
/// settings and the readiness thresholds. Route access (`RouteRoles`) is also
/// still role based: a permission switches actions inside a screen, it never
/// opens or closes a whole screen.
///
/// Overrides are an APP-side rule. Database row level security still follows
/// the person's role, so an Allow cannot make the database accept a write the
/// role could not make before.
///
/// The `key` strings are stored in the database and must never change.
enum Permission {
  signOffWork(
    key: 'sign_off_work',
    label: 'Sign off and finish work',
    description:
        'Sign inspections, maintenance and work orders, and mark jobs or '
        'tasks completed.',
    group: PermissionGroup.fieldWork,
    defaultRoles: {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
  ),
  deleteRecords(
    key: 'delete_records',
    label: 'Delete records',
    description: 'Delete maintenance records, schedule tasks and documents.',
    group: PermissionGroup.fieldWork,
    defaultRoles: {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
  ),
  deleteInspections(
    key: 'delete_inspections',
    label: 'Delete inspections',
    description: 'Delete inspections from the inspections list.',
    group: PermissionGroup.fieldWork,
    defaultRoles: {UserRole.dispatcher, UserRole.admin},
  ),
  assignSchedule(
    key: 'assign_schedule',
    label: 'Assign schedule tasks',
    description: 'Hand a schedule task to a technician or unassign it.',
    group: PermissionGroup.scheduleAndCustomers,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  manageCustomers(
    key: 'manage_customers',
    label: 'Edit customers and sites',
    description: 'Add and change customers and their sites.',
    group: PermissionGroup.scheduleAndCustomers,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  editPartsProfiles(
    key: 'edit_parts_profiles',
    label: 'Edit generator parts profiles',
    description:
        'Change a generator standing parts list directly, without a proposal.',
    group: PermissionGroup.scheduleAndCustomers,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  manageInventory(
    key: 'manage_inventory',
    label: 'Manage inventory',
    description:
        'Receive, adjust and count stock; edit the parts catalog, vendors, '
        'prices and purchase orders; see parts costs.',
    group: PermissionGroup.inventory,
    defaultRoles: {UserRole.admin},
  ),
  reserveStock(
    key: 'reserve_stock',
    label: 'Reserve and issue stock',
    description: 'Set parts aside for a job, issue them and take returns.',
    group: PermissionGroup.inventory,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  manageFleet(
    key: 'manage_fleet',
    label: 'Manage the fleet',
    description:
        'See every vehicle and add, edit and assign vehicles and their tools.',
    group: PermissionGroup.fleet,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  manageToolCatalog(
    key: 'manage_tool_catalog',
    label: 'Edit the tool catalog',
    description: 'Add and change the list of tools vehicles can carry.',
    group: PermissionGroup.fleet,
    defaultRoles: {UserRole.admin},
  ),
  scheduleReadiness(
    key: 'schedule_readiness',
    label: 'Schedule from generator readiness',
    description:
        'Schedule work and use bulk actions on the readiness dashboard.',
    group: PermissionGroup.analytics,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  ),
  viewWorkloadAnalytics(
    key: 'view_workload_analytics',
    label: 'See technician workload',
    description: 'The tasks-per-technician chart on Analytics.',
    group: PermissionGroup.analytics,
    defaultRoles: {UserRole.dispatcher, UserRole.admin},
  ),
  viewInventoryAnalytics(
    key: 'view_inventory_analytics',
    label: 'See inventory analytics',
    description: 'The parts-in-stock chart on Analytics.',
    group: PermissionGroup.analytics,
    defaultRoles: {UserRole.supervisor, UserRole.dispatcher, UserRole.admin},
  );

  const Permission({
    required this.key,
    required this.label,
    required this.description,
    required this.group,
    required this.defaultRoles,
  });

  /// Stable string stored in the database. Never rename.
  final String key;
  final String label;
  final String description;
  final PermissionGroup group;

  /// Roles that have this permission when nobody has overridden it.
  final Set<UserRole> defaultRoles;

  /// Whether [role] has this permission by default.
  bool defaultFor(UserRole? role) =>
      role != null && defaultRoles.contains(role);

  /// The permission with [key], or null for an unknown key (for example one
  /// added by a newer app version).
  static Permission? fromKey(Object? key) {
    for (final p in values) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// The catalogue of one group, in declared order.
  static List<Permission> inGroup(PermissionGroup group) =>
      [for (final p in values) if (p.group == group) p];
}

/// A person's override rows, keyed by permission.
typedef PermissionOverrides = Map<Permission, PermissionEffect>;

/// Parses override rows (`permission`, `effect`), ignoring unknown permissions
/// and effects, so a newer server never breaks an older app.
PermissionOverrides parseOverrideRows(Iterable<Map<String, dynamic>> rows) {
  final out = <Permission, PermissionEffect>{};
  for (final row in rows) {
    final p = Permission.fromKey(row['permission']);
    final e = PermissionEffect.fromWire(row['effect']);
    if (p != null && e != null) out[p] = e;
  }
  return out;
}

/// A role default with an override applied on top.
///
/// A signed-out session (no role) has nothing, and an override can not grant
/// it anything.
bool resolvePermission(
  UserRole? role,
  Permission permission,
  PermissionOverrides overrides,
) {
  if (role == null) return false;
  switch (overrides[permission]) {
    case PermissionEffect.allow:
      return true;
    case PermissionEffect.deny:
      return false;
    case null:
      return permission.defaultFor(role);
  }
}

/// Cache encoding: `{"sign_off_work":"allow", ...}`.
Map<String, String> encodeOverrides(PermissionOverrides overrides) => {
      for (final e in overrides.entries) e.key.key: e.value.wire,
    };

PermissionOverrides decodeOverrides(Object? raw) {
  if (raw is! Map) return const {};
  final out = <Permission, PermissionEffect>{};
  raw.forEach((k, v) {
    final p = Permission.fromKey(k);
    final e = PermissionEffect.fromWire(v);
    if (p != null && e != null) out[p] = e;
  });
  return out;
}
