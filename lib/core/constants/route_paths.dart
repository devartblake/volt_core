// Central list of route paths (and optional names) used by GoRouter,
// AppDrawer, and anywhere else you navigate.

class RoutePaths {
  // Auth
  static const String login = '/login';
  static const String forbidden = '/403';

  // Dashboard / home
  static const String dashboard = '/';

  // Inspections
  static const String inspections = '/inspections';
  static const String inspectionNew = '/inspections/new';
  static const String inspectionDetail = '/inspections/detail/:id';
  static const String inspectionsPending = '/inspections/pending';

  // Maintenance
  static const String maintenance = '/maintenance';
  static const String maintenanceNew = '/maintenance/new';
  static const String maintenanceDetail = '/maintenance/detail/:id';
  static const String maintenanceArchive = '/maintenance/archive';

  // Schedule
  static const String schedule = '/schedule';

  // Equipment / Nameplate
  static const String nameplateList = '/nameplate-list';
  static const String nameplateIntervals = '/nameplate/:inspectionId';
  static const String equipmentSearch = '/equipment/search';

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
  static const String login = 'login';
  static const String forbidden = 'forbidden';

  static const String dashboard = 'dashboard';

  static const String inspections = 'inspections';
  static const String inspectionNew = 'inspection_new';
  static const String inspectionDetail = 'inspection_detail';
  static const String inspectionsPending = 'inspections_pending';

  static const String maintenance = 'maintenance';
  static const String maintenanceNew = 'maintenance_new';
  static const String maintenanceDetail = 'maintenance_detail';
  static const String maintenanceArchive = 'maintenance_archive';

  static const String schedule = 'schedule';

  static const String nameplateList = 'nameplate_list';
  static const String nameplateIntervals = 'nameplate_intervals';
  static const String equipmentSearch = 'equipment_search';

  static const String selectionManagement = 'selection_management';
  static const String settings = 'settings';
  static const String about = 'about';
  static const String tenantsSettings = 'tenants_settings';

  static const String adminDashboard = 'admin_dashboard';
  static const String adminSettings = 'admin_settings';
  static const String adminTechnicians = 'admin_technicians';
}
