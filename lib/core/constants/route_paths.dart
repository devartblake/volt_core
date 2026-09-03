// Central list of route paths (and optional names) used by GoRouter,
// AppDrawer, and anywhere else you navigate.

class RoutePaths {
  RoutePaths._();

  // Auth
  static const String login = '/login';
  static const String forbidden = '/403';

  // Dashboard / home
  static const String dashboard = '/';

  // Tech dashboard
  static const String techDashboard = '/tech-dashboard';

  // Analytics
  static const String analytics = '/analytics';

  // Inspections
  static const String inspections = '/inspections';
  static const String inspectionNew = '/inspections/new';
  static const String inspectionEdit = '/inspections/edit/:id';
  static const String inspectionDetail = '/inspections/detail/:id';
  static const String inspectionsPending = '/inspections/pending';

  // Maintenance
  static const String maintenance = '/maintenance';
  static const String maintenanceNew = '/maintenance/new';
  static const String maintenanceDetail = '/maintenance/detail/:id';
  static const String maintenanceArchive = '/maintenance/archive';

  // Work orders
  static const String workOrders = '/work-orders';
  static const String workOrderNew = '/work-orders/new';
  static const String workOrderEdit = '/work-orders/edit/:id';

  // Templates
  static const String templates = '/templates';
  static const String templateResponse = '/field-forms/:templateSlug';
  static const String generatorInspectionPilot =
      '/field-forms/generator-inspection';
  static const String generatorMaintenancePilot =
      '/field-forms/generator-maintenance';

  // Schedule
  static const String schedule = '/schedule';

  /// Relative sub-route path under [schedule] (full path: `/schedule/task`).
  /// GoRouter sub-route paths must NOT start with '/'.
  static const String scheduleTask = 'task';
  static const String scheduleTaskDetail = 'detail/:id';

  // Equipment / Nameplate
  static const String nameplateList = '/nameplate-list';
  static const String nameplateIntervals = '/nameplate/:inspectionId';
  static const String equipmentSearch = '/equipment/search';
  static const String equipmentHistory = '/equipment/history/:id';

  // Fleet — vehicles, and (later phases) the assets carried in them.
  // Deliberately not under /equipment: that is the field-service assets we
  // inspect. See docs/fleet_and_vehicle_assets_plan.md §0.
  static const String fleet = '/fleet';

  /// Sub-route paths under [fleet]. GoRouter sub-paths must NOT start with '/'.
  static const String fleetNewSub = 'new';
  static const String fleetEditSub = 'edit/:id';
  static const String fleetDetailSub = 'detail/:id';

  /// Nested under [fleetDetailSub], so `:id` is inherited and there is no
  /// ambiguity with the literal-prefixed `new` / `edit` siblings.
  static const String fleetMaintenanceNewSub = 'maintenance/new';
  static const String fleetVehicleAssetsSub = 'assets';

  static const String fleetNew = '$fleet/new';
  static const String fleetEdit = '$fleet/edit/:id';
  static const String fleetDetail = '$fleet/detail/:id';
  static const String fleetMaintenanceNew = '$fleet/detail/:id/maintenance/new';
  static const String fleetVehicleAssets = '$fleet/detail/:id/assets';
  static const String fleetCatalog = '$fleet/catalog';

  // Customer / service-site directory
  static const String customerSites = '/customers-sites';

  // Documents
  static const String documents = '/documents';

  // Settings & config
  static const String selectionManagement = '/selection-management';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String tenants = '/tenants';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminSettings = '/admin/settings';
  static const String adminTechnicians = '/admin/technicians';
}

/// Optional: route name constants if you want them too.
/// These should match the `name:` properties in app_router.dart.
class RouteNames {
  RouteNames._();

  static const String login = 'login';
  static const String forbidden = 'forbidden';

  static const String dashboard = 'dashboard';
  static const String techDashboard = 'tech_dashboard';
  static const String analytics = 'analytics';

  static const String inspections = 'inspections';
  static const String inspectionNew = 'inspection_new';
  static const String inspectionEdit = 'inspection_edit';
  static const String inspectionDetail = 'inspection_detail';
  static const String inspectionsPending = 'inspections_pending';

  static const String maintenance = 'maintenance';
  static const String maintenanceNew = 'maintenance_new';
  static const String maintenanceDetail = 'maintenance_detail';
  static const String maintenanceArchive = 'maintenance_archive';

  static const String workOrders = 'work_orders';
  static const String workOrderNew = 'work_order_new';
  static const String workOrderEdit = 'work_order_edit';

  static const String templates = 'templates';
  static const String templateResponse = 'template_response';

  static const String schedule = 'schedule';
  static const String scheduleTask = 'schedule_task';
  static const String scheduleTaskDetail = 'schedule_task_detail';

  static const String nameplateList = 'nameplate_list';
  static const String nameplateIntervals = 'nameplate_intervals';
  static const String equipmentSearch = 'equipment_search';
  static const String equipmentHistory = 'equipment_history';
  static const String fleet = 'fleet';
  static const String fleetNew = 'fleet_vehicle_new';
  static const String fleetEdit = 'fleet_vehicle_edit';
  static const String fleetDetail = 'fleet_vehicle_detail';
  static const String fleetMaintenanceNew = 'fleet_maintenance_new';
  static const String fleetVehicleAssets = 'fleet_vehicle_assets';
  static const String fleetCatalog = 'fleet_catalog';
  static const String customerSites = 'customer_sites';

  static const String documents = 'documents';

  static const String selectionManagement = 'selection_management';
  static const String settings = 'settings';
  static const String about = 'about';
  static const String tenantsSettings = 'tenants_settings';

  static const String adminDashboard = 'admin_dashboard';
  static const String adminSettings = 'admin_settings';
  static const String adminTechnicians = 'admin_technicians';
}
