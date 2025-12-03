import 'package:go_router/go_router.dart';
import 'package:voltcore/features/maintenance/ui/pages/maintenance_form_page.dart';
import 'package:voltcore/features/maintenance/ui/pages/maintenance_list_page.dart';
import 'package:voltcore/features/settings/dashboard_page.dart';
import '../features/equipment/ui/pages/equipment_search_page.dart';
import '../features/inspections/ui/pages/inspection_list_page.dart';
import '../features/inspections/ui/pages/inspection_form_page.dart';
import '../features/inspections/ui/pages/inspection_detail_page.dart';
import '../features/inspections/ui/pages/nameplate_intervals_page.dart';
import '../features/inspections/ui/pages/nameplate_list_page.dart';
import '../features/maintenance/ui/pages/maintenance_archive_page.dart';
import '../features/maintenance/ui/pages/maintenance_detail_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/selection_options_page.dart';
import '../features/settings/settings_page.dart';

final appRouter = GoRouter(
  routes: [
    // ========================================
    // DASHBOARD
    // ========================================
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (_, __) => const DashboardPage(),
    ),

    // ========================================
    // INSPECTIONS
    // ========================================
    GoRoute(
      path: '/inspections',
      name: 'inspections',
      builder: (_, __) => const InspectionListPage(),
      routes: [
        // Create new inspection
        GoRoute(
          path: 'new',
          name: 'inspection_new',
          builder: (_, __) => const InspectionFormPage(),
        ),
        // Inspection detail
        GoRoute(
          path: 'detail/:id',
          name: 'inspection_detail',
          builder: (_, state) => InspectionDetailPage(
            id: state.pathParameters['id']!,
          ),
        ),
        // Pending inspections (filtered view)
        GoRoute(
          path: 'pending',
          name: 'inspections_pending',
          builder: (_, __) => const InspectionListPage(
            // TODO: Add filter parameter to show only pending
            // filterStatus: InspectionStatus.pending,
          ),
        ),
      ],
    ),

    // ========================================
    // MAINTENANCE
    // ========================================
    GoRoute(
      path: '/maintenance',
      name: 'maintenance',
      builder: (_, __) => const MaintenanceListPage(),
      routes: [
        // Create new maintenance job
        GoRoute(
          path: 'new',
          name: 'maintenance_new',
          builder: (_, state) => MaintenanceFormPage(
            id: state.uri.queryParameters['id'],
          ),
        ),
        // Maintenance detail
        GoRoute(
          path: 'detail/:id',
          name: 'maintenance_detail',
          builder: (_, state) => MaintenanceDetailPage(
            id: state.pathParameters['id']!,
          ),
        ),
        // Maintenance archive
        GoRoute(
          path: 'archive',
          name: 'maintenance_archive',
          builder: (_, __) => const MaintenanceArchivePage(),
        ),
      ],
    ),

    // ========================================
    // SCHEDULE
    // ========================================
    GoRoute(
      path: '/schedule',
      name: 'schedule',
      builder: (_, __) => const InspectionSchedulePage(),
    ),

    // ========================================
    // EQUIPMENT / NAMEPLATE
    // ========================================
    GoRoute(
      path: '/nameplate-list',
      name: 'nameplate_list',
      builder: (_, __) => const NameplateListPage(),
    ),
    GoRoute(
      path: '/nameplate/:inspectionId',
      name: 'nameplate_intervals',
      builder: (_, state) => NameplateIntervalsPage(
        inspectionId: state.pathParameters['inspectionId']!,
      ),
    ),
    // Equipment search (TODO: Create page if needed)
    GoRoute(
      path: '/equipment/search',
      name: 'equipment_search',
      builder: (_, __) => const EquipmentSearchPage(),
    ),

    // ========================================
    // SETTINGS & CONFIGURATION
    // ========================================
    GoRoute(
      path: '/selection-management',
      name: 'selection_management',
      builder: (_, __) => const SelectionOptionsPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (_, __) => const SettingsPage(),
    ),

    // ========================================
    // ABOUT
    // ========================================
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (_, __) => const AboutPage(),
    ),
  ],
);