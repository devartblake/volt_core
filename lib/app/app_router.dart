import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/app/app_shells.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/presenter/pages/login_page.dart';
import 'package:voltcore/modules/auth/presenter/pages/forbidden_page.dart';

import 'package:voltcore/modules/dashboard/presenter/pages/dashboard_page.dart';

import 'package:voltcore/modules/admin/presenter/pages/admin_dashboard_page.dart';
import 'package:voltcore/modules/admin/presenter/pages/admin_settings_page.dart';
import '../modules/admin/presenter/pages/technicians_page.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/dashboard/presenter/pages/tech_dashboard_page.dart';
import '../modules/equipment/presenter/pages/equipment_search_page.dart';
import '../modules/inspections/presenter/pages/inspection_detail_page.dart';
import '../modules/inspections/presenter/pages/inspection_form_page.dart';
import '../modules/inspections/presenter/pages/inspection_list_page.dart';
import '../modules/inspections/presenter/pages/nameplate_intervals_page.dart';
import '../modules/inspections/presenter/pages/nameplate_list_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_archive_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_detail_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_form_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_list_page.dart';
import '../modules/schedule/presenter/pages/schedule_page.dart';
import '../modules/settings/presenter/pages/about_page.dart';
import '../modules/settings/presenter/pages/selection_options_page.dart';
import '../modules/settings/presenter/pages/settings_page.dart';
import '../modules/settings/presenter/pages/tenants_settings_page.dart';

/// Exposed router provider used by `app.dart`:
///
/// ```dart
/// final router = ref.watch(goRouterProvider);
/// return MaterialApp.router(routerConfig: router, ...);
/// ```
final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.dashboard,
    debugLogDiagnostics: true,

    /// Global redirect:
    /// - Forces login when not authenticated
    /// - Sends logged-in users away from /login to /
    /// - Enforces RBAC with kRouteRoles (by *route name*) → /403
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final role = auth.currentRole;
      final path = state.uri.path;
      final routeName = state.name;

      const loginPath = RoutePaths.login;
      const forbiddenPath = RoutePaths.forbidden;

      final isLogin = path == loginPath;
      final isForbidden = path == forbiddenPath;

      // 1) Not logged in → force to /login (except when already on /login or /403)
      if (!isLoggedIn && !isLogin && !isForbidden) {
        return loginPath;
      }

      // 2) Logged in but at /login → send home
      if (isLoggedIn && isLogin) {
        return '/';
      }

      // 3) Role-based guard using kRouteRoles (by route name)
      //
      // We assume:
      //   const Map<String, Set<UserRole>> kRouteRoles = {...};
      // Where keys are the *route names* below (e.g. 'dashboard', 'inspections', etc.)
      if (isLoggedIn && !isForbidden && routeName != null) {
        final isAllowed = RouteRoles.isAllowedByName(
          name: routeName,
          role: role,
        );

        if (!isAllowed) {
          if (path == forbiddenPath) return null;
          return forbiddenPath;
        }
      }

      return null; // no-op redirect
    },

    routes: [
      // =====================
      // PUBLIC / AUTH PAGES
      // =====================
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.forbidden,
        name: RouteNames.forbidden,
        builder: (_, __) => const ForbiddenPage(),
      ),

      // ========== DASHBOARD (role-aware content inside) ==========
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (_, __) => const DefaultShell(
          child: DashboardPage(),
        ),
      ),
      GoRoute(
        path: '/tech-dashboard',
        name: 'tech_dashboard',
        builder: (_, __) => const TechShell(
          child: TechDashboardPage(),
        ),
      ),

      // ========== INSPECTIONS ==========
      GoRoute(
        path: RoutePaths.inspections,
        name: RouteNames.inspections,
        builder: (_, __) => const TechShell(
          child: InspectionListPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.inspectionNew,
            builder: (_, __) => const TechShell(
              child: InspectionFormPage(),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: RouteNames.inspectionDetail,
            builder: (_, state) => TechShell(
              child: InspectionDetailPage(
                id: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'pending',
            name: RouteNames.inspectionsPending,
            builder: (_, __) => const TechShell(
              child: InspectionListPage(
                // TODO: pending-filter
              ),
            ),
          ),
        ],
      ),

      // ========== MAINTENANCE ==========
      GoRoute(
        path: RoutePaths.maintenance,
        name: RouteNames.maintenance,
        builder: (_, __) => const TechShell(
          child: MaintenanceListPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.maintenanceNew,
            builder: (_, state) => TechShell(
              child: MaintenanceFormPage(
                id: state.uri.queryParameters['id'],
              ),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: RouteNames.maintenanceDetail,
            builder: (_, state) => TechShell(
              child: MaintenanceDetailPage(
                id: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'archive',
            name: RouteNames.maintenanceArchive,
            builder: (_, __) => const TechShell(
              child: MaintenanceArchivePage(),
            ),
          ),
        ],
      ),

      // ========== SCHEDULE ==========
      GoRoute(
        path: RoutePaths.schedule,
        name: RouteNames.schedule,
        builder: (_, __) => const TechShell(
          child: SchedulePage(),
        ),
      ),

      // ========== EQUIPMENT / NAMEPLATE ==========
      GoRoute(
        path: RoutePaths.nameplateList,
        name: RouteNames.nameplateList,
        builder: (_, __) => const TechShell(
          child: NameplateListPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.nameplateIntervals,
        name: RouteNames.nameplateIntervals,
        builder: (_, state) => TechShell(
          child: NameplateIntervalsPage(
            inspectionId: state.pathParameters['inspectionId']!,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.equipmentSearch,
        name: RouteNames.equipmentSearch,
        builder: (_, __) => const TechShell(
          child: EquipmentSearchPage(),
        ),
      ),

      // ========== SETTINGS & CONFIG ==========
      GoRoute(
        path: RoutePaths.selectionManagement,
        name: RouteNames.selectionManagement,
        builder: (_, __) => const DefaultShell(
          child: SelectionOptionsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (_, __) => const DefaultShell(
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        builder: (_, __) => const DefaultShell(
          child: AboutPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.tenants,
        name: RouteNames.tenantsSettings,
        builder: (_, __) => const DefaultShell(
          child: TenantsSettingsPage(),
        ),
      ),

      // ========== ADMIN ==========
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (_, __) => const AdminShell(
          child: AdminDashboardPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminSettings,
        name: RouteNames.adminSettings,
        builder: (_, __) => const AdminShell(
          child: AdminSettingsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminTechnicians,
        name: RouteNames.adminTechnicians,
        builder: (_, __) => const AdminShell(
          child: TechniciansPage(),
        ),
      ),
    ],
  );
});