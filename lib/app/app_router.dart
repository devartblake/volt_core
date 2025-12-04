import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/app/app_shells.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/modules/auth/presenter/pages/login_page.dart';
import 'package:voltcore/modules/auth/presenter/pages/forbidden_page.dart';

import 'package:voltcore/modules/dashboard/presenter/pages/dashboard_page.dart';

import 'package:voltcore/modules/admin/presenter/pages/admin_dashboard_page.dart';
import 'package:voltcore/modules/admin/presenter/pages/admin_settings_page.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
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

/// Exposed router provider used by `app.dart`:
///
/// ```dart
/// final router = ref.watch(goRouterProvider);
/// return MaterialApp.router(routerConfig: router, ...);
/// ```
final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
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

      const loginPath = '/login';
      const forbiddenPath = '/403';

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
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/403',
        name: 'forbidden',
        builder: (_, __) => const ForbiddenPage(),
      ),

      // =====================
      // DASHBOARD (role-aware content inside)
      // =====================
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (_, __) => const DefaultShell(
          child: DashboardPage(),
        ),
      ),

      // =====================
      // INSPECTIONS
      // =====================
      GoRoute(
        path: '/inspections',
        name: 'inspections',
        builder: (_, __) => const TechShell(
          child: InspectionListPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'inspection_new',
            builder: (_, __) => const TechShell(
              child: InspectionFormPage(),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: 'inspection_detail',
            builder: (_, state) => TechShell(
              child: InspectionDetailPage(
                id: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'pending',
            name: 'inspections_pending',
            builder: (_, __) => const TechShell(
              child: InspectionListPage(
                // TODO: add filter in page/controller for pending only
              ),
            ),
          ),
        ],
      ),

      // =====================
      // MAINTENANCE
      // =====================
      GoRoute(
        path: '/maintenance',
        name: 'maintenance',
        builder: (_, __) => const TechShell(
          child: MaintenanceListPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'maintenance_new',
            builder: (_, state) => TechShell(
              child: MaintenanceFormPage(
                id: state.uri.queryParameters['id'],
              ),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: 'maintenance_detail',
            builder: (_, state) => TechShell(
              child: MaintenanceDetailPage(
                id: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'archive',
            name: 'maintenance_archive',
            builder: (_, __) => const TechShell(
              child: MaintenanceArchivePage(),
            ),
          ),
        ],
      ),

      // =====================
      // SCHEDULE
      // =====================
      GoRoute(
        path: '/schedule',
        name: 'schedule',
        builder: (_, __) => const TechShell(
          child: SchedulePage(),
        ),
      ),

      // =====================
      // EQUIPMENT / NAMEPLATE
      // =====================
      GoRoute(
        path: '/nameplate-list',
        name: 'nameplate_list',
        builder: (_, __) => const TechShell(
          child: NameplateListPage(),
        ),
      ),
      GoRoute(
        path: '/nameplate/:inspectionId',
        name: 'nameplate_intervals',
        builder: (_, state) => TechShell(
          child: NameplateIntervalsPage(
            inspectionId: state.pathParameters['inspectionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/equipment/search',
        name: 'equipment_search',
        builder: (_, __) => const TechShell(
          child: EquipmentSearchPage(),
        ),
      ),

      // =====================
      // SETTINGS & CONFIG
      // =====================
      GoRoute(
        path: '/selection-management',
        name: 'selection_management',
        builder: (_, __) => const DefaultShell(
          child: SelectionOptionsPage(),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const DefaultShell(
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (_, __) => const DefaultShell(
          child: AboutPage(),
        ),
      ),

      // =====================
      // ADMIN AREA
      // =====================
      GoRoute(
        path: '/admin',
        name: 'admin_dashboard',
        builder: (_, __) => const AdminShell(
          child: AdminDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        name: 'admin_settings',
        builder: (_, __) => const AdminShell(
          child: AdminSettingsPage(),
        ),
      ),
    ],
  );
});