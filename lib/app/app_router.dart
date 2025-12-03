import 'package:go_router/go_router.dart';

// Existing imports
import 'package:voltcore/features/settings/dashboard_page.dart';
import '../../features/schedule/schedule_page.dart';
import '../../features/settings/about_page.dart';
import '../../features/settings/selection_options_page.dart';
import '../../features/settings/settings_page.dart';

// 🔐 NEW: RBAC helper + admin pages
import '../features/equipment/ui/pages/equipment_search_page.dart';
import '../features/inspections/ui/pages/inspection_detail_page.dart';
import '../features/inspections/ui/pages/inspection_form_page.dart';
import '../features/inspections/ui/pages/inspection_list_page.dart';
import '../features/inspections/ui/pages/nameplate_intervals_page.dart';
import '../features/inspections/ui/pages/nameplate_list_page.dart';
import '../features/maintenance/ui/pages/maintenance_archive_page.dart';
import '../features/maintenance/ui/pages/maintenance_detail_page.dart';
import '../features/maintenance/ui/pages/maintenance_form_page.dart';
import '../features/maintenance/ui/pages/maintenance_list_page.dart';
import '../modules/admin/presenter/pages/admin_dashboard_page.dart';
import '../modules/admin/presenter/pages/admin_settings_page.dart';
import 'role_guard.dart';
import '../../modules/auth/auth_state.dart'; // for UserRole enum

/// Global GoRouter instance.
///
/// NOTE:
/// If you later move to a Riverpod-based router provider, you can
/// wrap this in a Provider<GoRouter>. For now we keep the simple
/// top-level instance to avoid breaking your existing setup.
final appRouter = GoRouter(
  routes: [
    // ========================================
    // DASHBOARD (role-aware inside the page)
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
          path: '/detail/:id',
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
            // id is optional – if present we edit; if null we create.
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
    // ADMIN AREA (NEW)
    // ========================================
    // Admin dashboard – uses RoleGuard so only admins (or whichever
    // roles you include) can open it.
    GoRoute(
      path: '/admin',
      name: 'admin_dashboard',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {UserRole.admin, UserRole.dispatcher, UserRole.supervisor},
        path: '/admin',
        child: AdminDashboardPage(),
      ),
    ),

    // Admin settings – also protected
    GoRoute(
      path: '/admin/settings',
      name: 'admin_settings',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {UserRole.admin},
        path: '/admin/settings',
        child: AdminSettingsPage(),
      ),
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
