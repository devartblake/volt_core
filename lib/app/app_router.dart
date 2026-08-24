import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/app/app_shells.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/feature_flags.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/presenter/pages/login_page.dart';
import 'package:voltcore/modules/auth/presenter/pages/forbidden_page.dart';

import 'package:voltcore/modules/dashboard/presenter/pages/dashboard_page.dart';
import 'package:voltcore/modules/dashboard/presenter/pages/analytics_page.dart';

import 'package:voltcore/modules/admin/presenter/pages/admin_dashboard_page.dart';
import 'package:voltcore/modules/admin/presenter/pages/admin_settings_page.dart';
import '../modules/admin/presenter/pages/technicians_page.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/dashboard/presenter/pages/tech_dashboard_page.dart';
import '../modules/documents/presenter/pages/document_library_page.dart';
import '../modules/debug/pages/debug_menu_page.dart';
import '../modules/debug/pages/hive_debug_page.dart';
import '../modules/debug/pages/network_debug_page.dart';
import '../modules/customers/presenter/pages/customer_site_directory_page.dart';
import '../modules/equipment/presenter/pages/equipment_search_page.dart';
import '../modules/equipment/presenter/pages/asset_history_page.dart';
import '../modules/inspections/presenter/pages/inspection_detail_page.dart';
import '../modules/inspections/presenter/pages/inspection_form_page.dart';
import '../modules/inspections/presenter/pages/inspection_list_page.dart';
import '../modules/inspections/presenter/pages/nameplate_intervals_page.dart';
import '../modules/inspections/presenter/pages/nameplate_list_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_archive_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_detail_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_form_page.dart';
import '../modules/maintenance/presenter/pages/maintenance_list_page.dart';
import '../modules/work_orders/presenter/pages/work_order_form_page.dart';
import '../modules/work_orders/presenter/pages/work_order_list_page.dart';
import '../modules/schedule/presenter/pages/schedule_page.dart';
import '../modules/schedule/presenter/pages/schedule_task_detail_page.dart';
import '../modules/schedule/presenter/pages/schedule_task_page.dart';
import '../modules/settings/presenter/pages/about_page.dart';
import '../modules/settings/presenter/pages/selection_options_page.dart';
import '../modules/settings/presenter/pages/settings_page.dart';
import '../modules/settings/presenter/pages/tenants_settings_page.dart';
import '../modules/templates/presenter/pages/template_management_page.dart';
import '../modules/templates/presenter/pages/template_response_execution_page.dart';

/// Exposed router provider used by `app.dart`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.dashboard,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final role = auth.currentRole;
      final path = state.uri.path;
      final routeName = state.name;

      const loginPath = RoutePaths.login;
      const forbiddenPath = RoutePaths.forbidden;

      final isLogin = path == loginPath;
      final isForbidden = path == forbiddenPath;

      if (!isLoggedIn && !isLogin && !isForbidden) return loginPath;
      if (isLoggedIn && isLogin) return '/';

      if (isLoggedIn && !isForbidden && routeName != null) {
        final isAllowed = RouteRoles.isAllowedByName(name: routeName, role: role);
        if (!isAllowed) {
          if (path == forbiddenPath) return null;
          return forbiddenPath;
        }
      }
      return null;
    },
    routes: [
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
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (_, __) => const DefaultShell(child: DashboardPage()),
      ),
      GoRoute(
        path: RoutePaths.techDashboard,
        name: RouteNames.techDashboard,
        builder: (_, __) => const TechShell(child: TechDashboardPage()),
      ),
      GoRoute(
        path: RoutePaths.analytics,
        name: RouteNames.analytics,
        builder: (_, __) => const DefaultShell(child: AnalyticsPage()),
      ),
      GoRoute(
        path: RoutePaths.inspections,
        name: RouteNames.inspections,
        builder: (_, __) => const TechShell(child: InspectionListPage()),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.inspectionNew,
            builder: (_, __) => const TechShell(child: InspectionFormPage()),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.inspectionEdit,
            builder: (_, state) => TechShell(
              child: InspectionFormPage(inspectionId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: RouteNames.inspectionDetail,
            builder: (_, state) => TechShell(
              child: InspectionDetailPage(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'pending',
            name: RouteNames.inspectionsPending,
            builder: (_, __) => const TechShell(
              child: InspectionListPage(filterStatus: 'pending'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.maintenance,
        name: RouteNames.maintenance,
        builder: (_, __) => const TechShell(child: MaintenanceListPage()),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.maintenanceNew,
            builder: (_, state) => TechShell(
              child: MaintenanceFormPage(id: state.uri.queryParameters['id']),
            ),
          ),
          GoRoute(
            path: 'detail/:id',
            name: RouteNames.maintenanceDetail,
            builder: (_, state) => TechShell(
              child: MaintenanceDetailPage(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'archive',
            name: RouteNames.maintenanceArchive,
            builder: (_, __) => const TechShell(child: MaintenanceArchivePage()),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.workOrders,
        name: RouteNames.workOrders,
        builder: (_, __) => const TechShell(child: WorkOrderListPage()),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.workOrderNew,
            builder: (_, __) => const TechShell(child: WorkOrderFormPage()),
          ),
          GoRoute(
            path: 'edit/:id',
            name: RouteNames.workOrderEdit,
            builder: (_, state) => TechShell(
              child: WorkOrderFormPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.templates,
        name: RouteNames.templates,
        builder: (_, __) => const DefaultShell(child: TemplateManagementPage()),
      ),
      if (FeatureFlags.generatorTemplatePilotEnabled)
        GoRoute(
          path: RoutePaths.templateResponse,
          name: RouteNames.templateResponse,
          builder: (_, state) {
            final query = state.uri.queryParameters;
            return TechShell(
              child: TemplateResponseExecutionPage(
                templateSlug: state.pathParameters['templateSlug']!,
                responseId: query['responseId'],
                subjectType: query['subjectType'] ?? 'asset',
                subjectId: query['subjectId'],
                customerId: query['customerId'],
                siteId: query['siteId'],
                assetId: query['assetId'],
                workOrderId: query['workOrderId'],
                inspectionId: query['inspectionId'],
                maintenanceRecordId: query['maintenanceRecordId'],
              ),
            );
          },
        ),
      GoRoute(
        path: RoutePaths.schedule,
        name: RouteNames.schedule,
        builder: (_, __) => const TechShell(child: SchedulePage()),
        routes: [
          GoRoute(
            path: RoutePaths.scheduleTask,
            name: RouteNames.scheduleTask,
            builder: (_, __) => const TechShell(child: ScheduleTaskPage()),
          ),
          GoRoute(
            path: RoutePaths.scheduleTaskDetail,
            name: RouteNames.scheduleTaskDetail,
            builder: (_, state) => TechShell(
              child: ScheduleTaskDetailPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.nameplateList,
        name: RouteNames.nameplateList,
        builder: (_, __) => const TechShell(child: NameplateListPage()),
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
      if (FeatureFlags.equipmentSearchEnabled)
        GoRoute(
          path: RoutePaths.equipmentSearch,
          name: RouteNames.equipmentSearch,
          builder: (_, __) => const TechShell(child: EquipmentSearchPage()),
        ),
      if (FeatureFlags.equipmentSearchEnabled)
        GoRoute(
          path: RoutePaths.equipmentHistory,
          name: RouteNames.equipmentHistory,
          builder: (_, state) => TechShell(
            child: AssetHistoryPage(assetId: state.pathParameters['id']!),
          ),
        ),
      GoRoute(
        path: RoutePaths.customerSites,
        name: RouteNames.customerSites,
        builder: (_, __) => const DefaultShell(child: CustomerSiteDirectoryPage()),
      ),
      GoRoute(
        path: RoutePaths.documents,
        name: RouteNames.documents,
        builder: (_, __) => const TechShell(child: DocumentLibraryPage()),
      ),
      GoRoute(
        path: RoutePaths.selectionManagement,
        name: RouteNames.selectionManagement,
        builder: (_, __) => const DefaultShell(child: SelectionOptionsPage()),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (_, __) => const DefaultShell(child: SettingsPage()),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        builder: (_, __) => const DefaultShell(child: AboutPage()),
      ),
      GoRoute(
        path: RoutePaths.tenants,
        name: RouteNames.tenantsSettings,
        builder: (_, __) => const DefaultShell(child: TenantsSettingsPage()),
      ),
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (_, __) => const AdminShell(child: AdminDashboardPage()),
      ),
      GoRoute(
        path: RoutePaths.adminSettings,
        name: RouteNames.adminSettings,
        builder: (_, __) => const AdminShell(child: AdminSettingsPage()),
      ),
      GoRoute(
        path: RoutePaths.adminTechnicians,
        name: RouteNames.adminTechnicians,
        builder: (_, __) => const AdminShell(child: TechniciansPage()),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/debug',
          name: 'debug_menu',
          builder: (_, __) => const DebugMenuPage(),
          routes: [
            GoRoute(
              path: 'hive',
              name: 'hive_debug',
              builder: (_, __) => const HiveDebugPage(),
            ),
            GoRoute(
              path: 'network',
              name: 'network_debug',
              builder: (_, __) => const NetworkDebugPage(),
            ),
          ],
        ),
    ],
  );
});
