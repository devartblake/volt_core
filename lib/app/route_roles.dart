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
  static const Set<String> _publicRouteNames = {'login', 'forbidden'};

  static const Map<String, Set<UserRole>> _rolesByRouteName = {
    // ----- Core shell / dashboards -----
    'dashboard': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
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
    'inspection_edit': {
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

    // ----- Work orders -----
    'work_orders': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'work_order_new': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'work_order_edit': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Templates -----
    // Management is a UI affordance only; Supabase RLS and
    // can_manage_tenant_work remain the authoritative write boundary.
    'templates': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    // Field execution is technician work and is intentionally available to all
    // operational roles. The pilot feature flag controls whether the route is
    // registered at all during Phase 3 rollout.
    'template_response': {
      UserRole.tech,
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
    'schedule_task_detail': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },

    // ----- Fleet -----
    //
    // A technician is stationed to one vehicle: they are responsible for it
    // and its assets and they sign for it when it is dispatched, so they can
    // reach the list and the detail page. What they *see* there is narrowed to
    // their own vehicle by RLS (fleet_vehicles_read) and mirrored locally by
    // fleetVisibleVehiclesProvider — this map decides which screens open, not
    // which rows come back.
    //
    // Editing the fleet record stays with dispatch. The database agrees:
    // fleet_vehicles' write policies are gated on can_manage_tenant_work(),
    // which is exactly admin/supervisor/dispatcher.
    'fleet': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'fleet_vehicle_detail': {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    // Recording a check is data entry, so it follows the same rule as editing
    // the vehicle. Widening it to let a technician log their own walk-around
    // is a one-line change here plus one policy in the migration.
    'fleet_maintenance_new': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'fleet_vehicle_new': {
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    },
    'fleet_vehicle_edit': {
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
    'customer_sites': {
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
    'tenants_settings': {UserRole.admin},

    // ----- Debug tooling -----
    'debug_menu': {UserRole.admin},
    'hive_debug': {UserRole.admin},
    'network_debug': {UserRole.admin},
  };

  static bool isAllowedByName({
    required String? name,
    required UserRole? role,
  }) {
    if (name != null && _publicRouteNames.contains(name)) return true;
    if (name == null || role == null) return false;

    final allowed = _rolesByRouteName[name];
    if (allowed == null || allowed.isEmpty) return false;

    return allowed.contains(role);
  }

  static Set<String> get configuredRouteNames => _rolesByRouteName.keys.toSet();

  static Set<String> get publicRouteNames => _publicRouteNames;

  static Set<UserRole> rolesFor(String name) =>
      _rolesByRouteName[name] ?? const {};
}
