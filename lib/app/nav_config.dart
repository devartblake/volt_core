import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/feature_flags.dart';
import '../core/constants/route_paths.dart';
import '../modules/auth/domain/user_role.dart';
import 'route_roles.dart';

/// Public breakpoints
const double kCompactBreakpoint = 800.0;
const double kExpandedBreakpoint = 1200.0;

/// Below this height (a phone held sideways) a persistent rail would eat the
/// little vertical and horizontal room there is, so navigation stays a drawer.
const double kShortHeightBreakpoint = 500.0;

/// Whether navigation should be a slide-out drawer rather than a fixed rail.
/// Shared by the shell and the drawer so they always agree, in portrait and
/// landscape.
bool isCompactLayout(Size size) =>
    size.width < kCompactBreakpoint || size.height < kShortHeightBreakpoint;

/// Navigation item model
class NavItem {
  final String label;
  final IconData icon;

  /// Path used with GoRouter (e.g. '/inspections')
  final String route;

  /// Optional named route used for RBAC lookups.
  /// This should match the `name:` you give to GoRoute in app_router.dart.
  final String? routeName;

  /// Optional tooltip / description
  final String? description;

  /// Visually nest an item below its operational parent in the drawer.
  final bool isSubItem;

  const NavItem(
      this.label,
      this.icon,
      this.route, {
        this.routeName,
        this.description,
        this.isSubItem = false,
      });
}

/// Navigation section for logical grouping
class NavSection {
  final String? title; // null for sections without headers
  final List<NavItem> items;

  /// How the section appears as a single destination on the tablet rail.
  /// Falls back to [title]. The rail shows one labelled entry per section;
  /// the section's other pages are tabs inside it (see [SectionNav]).
  final String? railLabel;
  final IconData? railIcon;

  const NavSection({
    this.title,
    required this.items,
    this.railLabel,
    this.railIcon,
  });

  String get destinationLabel => railLabel ?? title ?? items.first.label;
  IconData get destinationIcon => railIcon ?? items.first.icon;
}

/// Main navigation structure with logical grouping
///
/// NOTE: `routeName` must match the GoRoute.name in app_router.dart
/// so that RouteRoles can apply RBAC correctly.
const List<NavSection> navSections = [
  // Home: the dashboard, with analytics one tab away.
  NavSection(
    title: 'Home',
    railIcon: Icons.dashboard_outlined,
    items: [
      NavItem(
        'Dashboard',
        Icons.dashboard_outlined,
        RoutePaths.dashboard,
        routeName: 'dashboard',
        description: 'Overview and quick stats',
      ),
      NavItem(
        'Analytics',
        Icons.insights_outlined,
        RoutePaths.analytics,
        routeName: 'analytics',
        description: 'Inspection, maintenance & schedule metrics',
      ),
      NavItem(
        'Generator Fleet Readiness',
        Icons.verified_outlined,
        RoutePaths.readiness,
        routeName: RouteNames.readiness,
        description: 'Which generators are ready, due or need attention',
      ),
    ],
  ),

  // "Create Inspection" is the New Inspection button on this list (and a
  // quick action), so it no longer takes a menu entry of its own.
  NavSection(
    title: 'Inspections',
    railIcon: Icons.fact_check_outlined,
    items: [
      NavItem(
        'Inspections',
        Icons.fact_check_outlined,
        RoutePaths.inspections,
        routeName: 'inspections',
        description: 'Inspection history and new inspections',
      ),
      NavItem(
        'Pending Reviews',
        Icons.pending_actions_outlined,
        RoutePaths.inspectionsPending,
        routeName: 'inspections_pending',
        description: 'Items awaiting review',
      ),
    ],
  ),

  // Jobs, maintenance records, the schedule and the archive were four menu
  // entries in two places; they are one place now. "Create Job" is the New
  // button on the Jobs list (and a quick action).
  NavSection(
    title: 'Work',
    railIcon: Icons.work_outline,
    items: [
      NavItem(
        'Jobs',
        Icons.work_outline,
        RoutePaths.workOrders,
        routeName: RouteNames.workOrders,
        description: 'View and manage field work orders',
      ),
      NavItem(
        'Maintenance',
        Icons.build_circle_outlined,
        RoutePaths.maintenance,
        routeName: RouteNames.maintenance,
        description: 'Generator maintenance records and reports',
      ),
      NavItem(
        'Schedule',
        Icons.calendar_month_outlined,
        RoutePaths.schedule,
        routeName: 'schedule',
        description: 'Maintenance schedule',
      ),
      NavItem(
        'Archive',
        Icons.archive_outlined,
        RoutePaths.maintenanceArchive,
        routeName: RouteNames.maintenanceArchive,
        description: 'View & export previous maintenance',
      ),
      NavItem(
        'Documents',
        Icons.folder_open_outlined,
        RoutePaths.documents,
        routeName: 'documents',
        description: 'Generated PDF reports',
      ),
    ],
  ),

  NavSection(
    title: 'Fleet',
    railIcon: Icons.local_shipping_outlined,
    items: [
      NavItem(
        'Vehicles',
        Icons.local_shipping_outlined,
        RoutePaths.fleet,
        routeName: RouteNames.fleet,
        description: 'Vans and trucks, and who is stationed to them',
      ),
      NavItem(
        'Inspection Log',
        Icons.fact_check_outlined,
        RoutePaths.fleetInspectionLog,
        routeName: RouteNames.fleetInspectionLog,
        description: 'Daily, weekly and monthly inspections for each vehicle',
      ),
      NavItem(
        'Tool Catalog',
        Icons.handyman_outlined,
        RoutePaths.fleetCatalog,
        routeName: RouteNames.fleetCatalog,
        description: 'Tool types vans carry',
      ),
    ],
  ),

  // Customers and the equipment installed at their sites were two sections
  // with one entry each.
  NavSection(
    title: 'Customers & Equipment',
    railLabel: 'Customers',
    railIcon: Icons.business_outlined,
    items: [
      NavItem(
        'Customers & Sites',
        Icons.business_outlined,
        RoutePaths.customerSites,
        routeName: RouteNames.customerSites,
        description: 'Customer contacts and service locations',
      ),
      NavItem(
        'Equipment',
        Icons.inventory_2_outlined,
        RoutePaths.nameplateList,
        routeName: 'nameplate_list',
        description: 'Equipment database',
      ),
      // Supervisors, dispatchers and admins only (see RouteRoles).
      NavItem(
        'Parts approvals',
        Icons.rate_review_outlined,
        RoutePaths.materialsApprovals,
        routeName: RouteNames.materialsApprovals,
        description: 'Technicians\' proposed changes to generator parts profiles',
      ),
      // Hidden until backed by real data - see FeatureFlags.equipmentSearchEnabled.
      if (FeatureFlags.equipmentSearchEnabled)
        NavItem(
          'Asset Search',
          Icons.search_outlined,
          RoutePaths.equipmentSearch,
          routeName: 'equipment_search',
          description: 'Find equipment',
        ),
    ],
  ),

  // Parts and stock. Everyone can look (a technician checks what is on the
  // shelf before a job); only admins receive, adjust and edit the catalog.
  NavSection(
    title: 'Inventory',
    railIcon: Icons.warehouse_outlined,
    items: [
      NavItem(
        'Stock',
        Icons.inventory_outlined,
        RoutePaths.inventory,
        routeName: RouteNames.inventory,
        description: 'What is in the warehouse',
      ),
      NavItem(
        'Job Needs',
        Icons.assignment_outlined,
        RoutePaths.inventoryNeeds,
        routeName: RouteNames.inventoryNeeds,
        description: 'Parts each job needs and whether they are in stock',
      ),
      NavItem(
        'Shortages',
        Icons.shopping_cart_outlined,
        RoutePaths.inventoryShortages,
        routeName: RouteNames.inventoryShortages,
        description: 'What to order: job shortages and low stock',
      ),
      NavItem(
        'Parts Catalog',
        Icons.menu_book_outlined,
        RoutePaths.inventoryCatalog,
        routeName: RouteNames.inventoryCatalog,
        description: 'Part numbers, names and alternates',
      ),
      NavItem(
        'Orders',
        Icons.receipt_long_outlined,
        RoutePaths.inventoryOrders,
        routeName: RouteNames.inventoryOrders,
        description: 'Purchase orders: what is on order, and receiving it',
      ),
      NavItem(
        'Vendors',
        Icons.storefront_outlined,
        RoutePaths.inventoryVendors,
        routeName: RouteNames.inventoryVendors,
        description: 'Who parts are bought from, and prices paid',
      ),
      NavItem(
        'Movements',
        Icons.swap_vert,
        RoutePaths.inventoryMovements,
        routeName: RouteNames.inventoryMovements,
        description: 'The stock ledger and parts usage reports',
      ),
    ],
  ),

  // Settings, configuration and about were split across "System" and a
  // second trailing item; one section, three tabs.
  NavSection(
    title: 'Settings',
    railIcon: Icons.settings_outlined,
    items: [
      NavItem(
        'Settings',
        Icons.settings_outlined,
        RoutePaths.settings,
        routeName: 'settings',
        description: 'App settings',
      ),
      NavItem(
        'Configuration',
        Icons.tune_outlined,
        RoutePaths.selectionManagement,
        routeName: 'selection_management',
        description: 'System configuration',
      ),
      NavItem(
        'About',
        Icons.info_outline,
        RoutePaths.about,
        routeName: 'about',
        description: 'App information',
      ),
    ],
  ),

  // Administration - every item here is admin-only in RouteRoles, so the whole
  // section disappears for other roles (empty sections are dropped).
  NavSection(
    title: 'Administration',
    railLabel: 'Admin',
    railIcon: Icons.admin_panel_settings_outlined,
    items: [
      NavItem(
        'Admin Overview',
        Icons.admin_panel_settings_outlined,
        RoutePaths.adminDashboard,
        routeName: RouteNames.adminDashboard,
        description: 'Admin overview & controls',
      ),
      NavItem(
        'Technicians',
        Icons.engineering_outlined,
        RoutePaths.adminTechnicians,
        routeName: RouteNames.adminTechnicians,
        description: 'Team roster & role assignment',
      ),
      NavItem(
        'Tenants',
        Icons.apartment_outlined,
        RoutePaths.tenants,
        routeName: RouteNames.tenantsSettings,
        description: 'Organisations & sites',
      ),
      NavItem(
        'Admin Settings',
        Icons.security_outlined,
        RoutePaths.adminSettings,
        routeName: RouteNames.adminSettings,
        description: 'Advanced settings',
      ),
    ],
  ),
];

/// Quick action items (shown separately in compact mode)
const List<NavItem> quickActions = [
  NavItem(
    'Create Inspection',
    Icons.add_circle,
    RoutePaths.inspectionNew,
    routeName: 'inspection_new',
  ),
  NavItem(
    'Create Job',
    Icons.add_task,
    RoutePaths.workOrderNew,
    routeName: RouteNames.workOrderNew,
  ),
];

// ===== Helper functions =====

/// Filter nav sections by role using RouteRoles.
///
/// Fails closed, matching the router guard: with no role (not signed in yet)
/// nothing is offered, and an item without a `routeName` can't be RBAC-checked
/// so it is hidden rather than shown to everyone. Sections left with no visible
/// items are dropped, so a technician never sees an empty "Administration"
/// heading.
List<NavSection> visibleNavSectionsForRole(UserRole? role) {
  if (role == null) return const [];

  final result = <NavSection>[];

  for (final section in navSections) {
    final visibleItems = section.items.where((item) {
      final name = item.routeName;
      if (name == null) return false;
      return RouteRoles.isAllowedByName(name: name, role: role);
    }).toList();

    if (visibleItems.isNotEmpty) {
      result.add(
        NavSection(
          title: section.title,
          items: visibleItems,
          railLabel: section.railLabel,
          railIcon: section.railIcon,
        ),
      );
    }
  }

  return result;
}

/// Filter quick actions by role as well. Same fail-closed rule.
List<NavItem> visibleQuickActionsForRole(UserRole? role) {
  if (role == null) return const [];

  return quickActions.where((item) {
    final name = item.routeName;
    if (name == null) return false;
    return RouteRoles.isAllowedByName(name: name, role: role);
  }).toList();
}

/// A nested detail route must select its most specific destination. For
/// example, `/maintenance/archive` selects Archive rather than its broader
/// `/maintenance` parent, and `/inspections/pending` selects Pending Reviews.
NavItem? selectedNavItemForRoute(
  String location,
  List<NavSection> sections,
) {
  NavItem? selected;
  for (final item in sections.expand((section) => section.items)) {
    if (routeEquals(location, item.route) &&
        (selected == null || item.route.length > selected.route.length)) {
      selected = item;
    }
  }
  return selected;
}

bool routeEquals(String location, String route) =>
    location == route || location.startsWith('$route/');

String currentNavLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return '/';
  }
}

void goToRoute(BuildContext context, String route) {
  final loc = currentNavLocation(context);
  if (!routeEquals(loc, route)) {
    context.go(route);
  }
}


/// The pages of one navigation section, for the tab bar at the top of a page.
class SectionNav {
  const SectionNav({required this.items, required this.selected});

  final List<NavItem> items;
  final NavItem? selected;
}

/// The sections [role] may see (RBAC-filtered, empty sections dropped).
List<NavSection> navSectionsForRole(UserRole? role) =>
    visibleNavSectionsForRole(role);

/// The tabs for the section containing [location], or null when that section
/// has only one visible page (nothing to switch between).
SectionNav? sectionNavFor(UserRole? role, String location) {
  final sections = visibleNavSectionsForRole(role);
  final selected = selectedNavItemForRoute(location, sections);
  if (selected == null) return null;
  for (final section in sections) {
    if (section.items.any((i) => i.route == selected.route)) {
      if (section.items.length < 2) return null;
      return SectionNav(items: section.items, selected: selected);
    }
  }
  return null;
}

