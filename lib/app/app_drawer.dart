import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/feature_flags.dart';
import '../core/constants/route_paths.dart';
import '../modules/auth/domain/user_role.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import 'route_roles.dart';

/// Public breakpoints
const double kCompactBreakpoint = 800.0;
const double kExpandedBreakpoint = 1200.0;

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

  const NavItem(
      this.label,
      this.icon,
      this.route, {
        this.routeName,
        this.description,
      });
}

/// Navigation section for logical grouping
class NavSection {
  final String? title; // null for sections without headers
  final List<NavItem> items;

  const NavSection({
    this.title,
    required this.items,
  });
}

/// Main navigation structure with logical grouping
///
/// NOTE: `routeName` must match the GoRoute.name in app_router.dart
/// so that RouteRoles can apply RBAC correctly.
const List<NavSection> _navSections = [
  // Primary Actions (no header for main items)
  NavSection(
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
    ],
  ),

  // Inspections Group
  NavSection(
    title: 'Inspections',
    items: [
      NavItem(
        'All Inspections',
        Icons.fact_check_outlined,
        RoutePaths.inspections,
        routeName: 'inspections',
        description: 'View inspection history',
      ),
      NavItem(
        'Create Inspection',
        Icons.add_circle_outline,
        RoutePaths.inspectionNew,
        routeName: 'inspection_new',
        description: 'Start a new inspection',
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

  // Maintenance Group
  NavSection(
    title: 'Maintenance',
    items: [
      NavItem(
        'All Jobs',
        Icons.work_outline,
        RoutePaths.workOrders,
        routeName: RouteNames.workOrders,
        description: 'View and manage field work orders',
      ),
      NavItem(
        'Schedule',
        Icons.calendar_month_outlined,
        RoutePaths.schedule,
        routeName: 'schedule',
        description: 'Maintenance schedule',
      ),
      NavItem(
        'Create Job',
        Icons.add_task_outlined,
        RoutePaths.workOrderNew,
        routeName: RouteNames.workOrderNew,
        description: 'Create a field work order',
      ),
      NavItem(
        'Archive',
        Icons.archive_outlined,
        '/maintenance/archive',
        routeName: 'maintenance_archive',
        description: 'View & export previous maintenance',
      ),
    ],
  ),

  // Equipment Group
  NavSection(
    title: 'Directory',
    items: [
      NavItem(
        'Customers & Sites',
        Icons.business_outlined,
        RoutePaths.customerSites,
        routeName: RouteNames.customerSites,
        description: 'Customer contacts and service locations',
      ),
    ],
  ),

  NavSection(
    title: 'Equipment',
    items: [
      NavItem(
        'Registry',
        Icons.inventory_2_outlined,
        RoutePaths.nameplateList,
        routeName: 'nameplate_list',
        description: 'Equipment database',
      ),
      // Hidden until backed by real data — see FeatureFlags.equipmentSearchEnabled.
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

  // System Group
  NavSection(
    title: 'System',
    items: [
      NavItem(
        'Documents',
        Icons.folder_open_outlined,
        RoutePaths.documents,
        routeName: 'documents',
        description: 'Generated PDF reports',
      ),
      NavItem(
        'Configuration',
        Icons.tune_outlined,
        RoutePaths.selectionManagement,
        routeName: 'selection_management',
        description: 'System configuration',
      ),
      NavItem(
        'Settings',
        Icons.settings_outlined,
        RoutePaths.settings,
        routeName: 'settings',
        description: 'App settings',
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

  // Administration — every item here is admin-only in RouteRoles, so the whole
  // section disappears for other roles (empty sections are dropped).
  NavSection(
    title: 'Administration',
    items: [
      NavItem(
        'Admin Dashboard',
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
const List<NavItem> _quickActions = [
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

/// User profile model
class AppUserProfile {
  final String displayName;
  final String email;
  final String? avatarUrl;

  /// Active tenant name, or null when none is known yet (still loading, or the
  /// account has no tenant membership). The UI omits the row rather than
  /// showing a placeholder.
  final String? currentTenant;
  final List<String> tenants;
  final String? role; // Optional user role label

  const AppUserProfile({
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.currentTenant,
    this.tenants = const [],
    this.role,
  });
}

/// Modern responsive drawer with sections (role-aware)
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    this.trailing,
    this.onTapAny,
    this.badges,
    this.userProfile,
    this.onSwitchTenant,
    this.companyName = 'Voltcore',
    this.companySubtitle = 'Inspection Management',
    this.showQuickActions = true,
  });

  final Widget? trailing;
  final VoidCallback? onTapAny;
  final Map<String, int>? badges;
  final AppUserProfile? userProfile;
  final ValueChanged<String>? onSwitchTenant;
  final String companyName;
  final String companySubtitle;
  final bool showQuickActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < kCompactBreakpoint;
    final isExtended = width >= kExpandedBreakpoint;
    final current = _currentLocation(context);

    final auth = ref.watch(authStateProvider);
    final UserRole? role = auth.currentRole;

    final sections = _visibleNavSectionsForRole(role);
    final quickActions = _visibleQuickActionsForRole(role);

    if (isCompact) {
      return _buildCompactDrawer(
        context,
        current,
        sections,
        quickActions,
      );
    }
    return _buildNavigationRail(
      context,
      current,
      isExtended,
      sections,
    );
  }

  /// Compact drawer for mobile
  Widget _buildCompactDrawer(
      BuildContext context,
      String current,
      List<NavSection> sections,
      List<NavItem> quickActions,
      ) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _ModernDrawerHeader(
              companyName: companyName,
              companySubtitle: companySubtitle,
            ),

            // Quick Actions (FAB-style buttons)
            if (showQuickActions)
              _QuickActionsBar(
                actions: quickActions,
                onTap: (route) {
                  context.go(route);
                  (onTapAny ?? () => Navigator.of(context).maybePop()).call();
                },
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final section in sections) ...[
                    if (section.title != null)
                      _SectionHeader(title: section.title!),
                    for (final item in section.items)
                      _ModernDrawerTile(
                        item: item,
                        selected: _routeEquals(current, item.route),
                        count: (badges ?? const {})[item.route] ?? 0,
                        onTap: () {
                          _goTo(context, item.route);
                          (onTapAny ?? () => Navigator.of(context).maybePop())
                              .call();
                        },
                      ),
                    if (section.title != null) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            if (userProfile != null)
              _ProfileFooter(userProfile!, onSwitchTenant),
          ],
        ),
      ),
    );
  }

  /// Navigation rail for desktop / large layouts
  ///
  /// Wrapped in a scrollable container to avoid vertical overflow.
  Widget _buildNavigationRail(
      BuildContext context,
      String current,
      bool isExtended,
      List<NavSection> sections,
      ) {
    // Flatten all items for rail
    final allItems = sections.expand((s) => s.items).toList();
    final selectedIndex = _indexForRoute(current, allItems);

    return SafeArea(
      child: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: isExtended,
                      labelType: isExtended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.selected,
                      selectedIndex:
                      selectedIndex.clamp(0, allItems.length - 1),
                      onDestinationSelected: (i) =>
                          _goTo(context, allItems[i].route),
                      leading: Padding(
                        padding:
                        const EdgeInsets.only(top: 16.0, bottom: 16.0),
                        child: _AppBrand(
                          isExtended: isExtended,
                          companyName: companyName,
                        ),
                      ),
                      trailing: trailing ??
                          (userProfile != null
                              ? Padding(
                            padding:
                            const EdgeInsets.only(bottom: 16.0),
                            child: _ProfileMini(
                              userProfile!,
                              onSwitchTenant,
                            ),
                          )
                              : null),
                      destinations: [
                        for (final item in allItems)
                          NavigationRailDestination(
                            icon: _BadgeIcon(
                              icon: item.icon,
                              count:
                              (badges ?? const {})[item.route] ?? 0,
                            ),
                            selectedIcon: _BadgeIcon(
                              icon: item.icon,
                              count:
                              (badges ?? const {})[item.route] ?? 0,
                              selected: true,
                            ),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1),
        ],
      ),
    );
  }
}

/// Section header for grouped navigation
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Quick action buttons bar
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    required this.actions,
    required this.onTap,
  });

  final List<NavItem> actions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => onTap(actions[i].route),
                icon: Icon(actions[i].icon, size: 20),
                label: Text(
                  actions[i].label.replaceAll('Create ', ''),
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (i < actions.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Modern drawer header
class _ModernDrawerHeader extends StatelessWidget {
  const _ModernDrawerHeader({
    required this.companyName,
    required this.companySubtitle,
  });

  final String companyName;
  final String companySubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.bolt,
              color: colorScheme.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  companyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  companySubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                    colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern drawer tile
class _ModernDrawerTile extends StatelessWidget {
  const _ModernDrawerTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.count,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final trailing = count > 0
        ? Badge(
      label: Text('$count'),
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
    )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color:
          selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          item.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        subtitle: item.description != null && selected
            ? Text(
          item.description!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        )
            : null,
        selected: selected,
        trailing: trailing,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Badge icon for navigation rail
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    this.selected = false,
  });

  final IconData icon;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ic = Icon(
      icon,
      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
    );
    if (count <= 0) return ic;
    return Badge(
      label: Text('$count'),
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      child: ic,
    );
  }
}

/// App brand
class _AppBrand extends StatelessWidget {
  const _AppBrand({
    required this.isExtended,
    required this.companyName,
  });

  final bool isExtended;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isExtended) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bolt,
                size: 24,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              companyName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.bolt,
        size: 24,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Profile footer for drawer
class _ProfileFooter extends ConsumerWidget {
  const _ProfileFooter(this.profile, this.onSwitchTenant);

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final auth = ref.watch(authStateProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Icon(
                  Icons.person_outline,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.role != null)
                    _RoleLine(
                      role: auth.currentRole,
                      grantedRoles: auth.grantedRoles,
                      label: profile.role!,
                    ),
                  Text(
                    profile.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (profile.currentTenant != null)
                  Row(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.currentTenant!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.tenants.length > 1)
                        IconButton(
                          icon:
                          const Icon(Icons.swap_horiz, size: 20),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => _TenantSwitcher(
                                profile: profile,
                                onSwitchTenant: onSwitchTenant,
                              ),
                            );
                          },
                          tooltip: 'Switch tenant',
                          // Keep the 48dp minimum — this is a gloved,
                          // outdoors app; the zeroed constraints it had
                          // before made the target ~20dp.
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: kMinInteractiveDimension,
                            minHeight: kMinInteractiveDimension,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current role, tappable when the account holds more than one.
///
/// Roles come from the server (`tenant_members`); this only chooses which of
/// the user's own grants the session acts as, and [AuthController.switchRole]
/// refuses anything not granted.
class _RoleLine extends ConsumerWidget {
  const _RoleLine({
    required this.role,
    required this.grantedRoles,
    required this.label,
  });

  final UserRole? role;
  final Set<UserRole> grantedRoles;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w500,
    );

    // Single-role accounts (the common case) just read the role.
    if (grantedRoles.length < 2) {
      return Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _RoleSwitcher(
          current: role,
          granted: grantedRoles,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the roles this account actually holds.
class _RoleSwitcher extends ConsumerWidget {
  const _RoleSwitcher({required this.current, required this.granted});

  final UserRole? current;
  final Set<UserRole> granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Most privileged first, so the common "act as admin" is at the top.
    final roles = granted.toList()
      ..sort((a, b) => b.privilege.compareTo(a.privilege));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Act as',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Switching changes which screens are available. Your access is '
              'set by your organisation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final role in roles)
            ListTile(
              leading: Icon(
                role == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: role == current ? theme.colorScheme.primary : null,
              ),
              title: Text(role.label),
              onTap: () {
                ref.read(authStateProvider.notifier).switchRole(role);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tenant switcher bottom sheet
class _TenantSwitcher extends StatelessWidget {
  const _TenantSwitcher({
    required this.profile,
    required this.onSwitchTenant,
  });

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apartment_outlined,
                  color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Switch Tenant',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...profile.tenants.map((tenant) {
            final isSelected = tenant == profile.currentTenant;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                tenant,
                style: TextStyle(
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                onSwitchTenant?.call(tenant);
                Navigator.of(context).pop();
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Profile mini for rail
class _ProfileMini extends StatelessWidget {
  const _ProfileMini(this.profile, this.onSwitchTenant);

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Icon(
              Icons.person_outline,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        if (profile.tenants.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Switch tenant',
            icon: Icon(
              Icons.swap_horiz,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            onSelected: (t) => onSwitchTenant?.call(t),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (ctx) => [
              for (final t in profile.tenants)
                PopupMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(
                        t == profile.currentTenant
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: t == profile.currentTenant
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t,
                        style: TextStyle(
                          fontWeight: t == profile.currentTenant
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ===== Helper functions =====

/// Filter nav sections by role using RouteRoles.
///
/// Fails closed, matching the router guard: with no role (not signed in yet)
/// nothing is offered, and an item without a `routeName` can't be RBAC-checked
/// so it is hidden rather than shown to everyone. Sections left with no visible
/// items are dropped, so a technician never sees an empty "Administration"
/// heading.
List<NavSection> _visibleNavSectionsForRole(UserRole? role) {
  if (role == null) return const [];

  final result = <NavSection>[];

  for (final section in _navSections) {
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
        ),
      );
    }
  }

  return result;
}

/// Filter quick actions by role as well. Same fail-closed rule.
List<NavItem> _visibleQuickActionsForRole(UserRole? role) {
  if (role == null) return const [];

  return _quickActions.where((item) {
    final name = item.routeName;
    if (name == null) return false;
    return RouteRoles.isAllowedByName(name: name, role: role);
  }).toList();
}

int _indexForRoute(String location, List<NavItem> items) {
  for (var i = 0; i < items.length; i++) {
    if (_routeEquals(location, items[i].route)) return i;
  }
  return 0;
}

bool _routeEquals(String location, String route) =>
    location == route || location.startsWith('$route/');

String _currentLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.toString();
  } catch (_) {
    return '/';
  }
}

void _goTo(BuildContext context, String route) {
  final loc = _currentLocation(context);
  if (!_routeEquals(loc, route)) {
    context.go(route);
  }
}
