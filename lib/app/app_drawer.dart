import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../modules/auth/domain/user_role.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import 'nav_config.dart';
import 'nav_profile.dart';
import 'nav_widgets.dart';

export 'nav_config.dart';
export 'nav_profile.dart' show AppUserProfile;

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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isCompact = isCompactLayout(size);
    final isExtended = width >= kExpandedBreakpoint;
    final current = currentNavLocation(context);

    final UserRole? role =
        ref.watch(authStateProvider.select((a) => a.currentRole));

    final sections = visibleNavSectionsForRole(role);
    final quickActions = visibleQuickActionsForRole(role);

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
    final selectedItem = selectedNavItemForRoute(current, sections);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ModernDrawerHeader(
              companyName: companyName,
              companySubtitle: companySubtitle,
            ),

            // Quick Actions (FAB-style buttons)
            if (showQuickActions)
              QuickActionsBar(
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
                    DrawerSection(
                      section: section,
                      selectedItem: selectedItem,
                      badges: badges ?? const {},
                      onTap: (item) {
                        goToRoute(context, item.route);
                        (onTapAny ?? () => Navigator.of(context).maybePop())
                            .call();
                      },
                    ),
                  ],
                ],
              ),
            ),

            if (userProfile != null)
              ProfileFooter(userProfile!, onSwitchTenant),
          ],
        ),
      ),
    );
  }

  /// Pending-work count shown on a section's rail icon: the sum of its pages.
  int _sectionBadge(NavSection section) => section.items.fold<int>(
        0,
        (sum, i) => sum + ((badges ?? const {})[i.route] ?? 0),
      );

  /// Navigation rail for desktop / large layouts
  ///
  /// Wrapped in a scrollable container to avoid vertical overflow.
  Widget _buildNavigationRail(
      BuildContext context,
      String current,
      bool isExtended,
      List<NavSection> sections,
      ) {
    if (isExtended) {
      return _buildExpandedNavigation(context, current, sections);
    }

    // One labelled destination per section. Each section's other pages are
    // tabs at the top of the page (see SectionNav), so the rail stays short
    // enough to read instead of a column of unlabeled icons.
    final selectedItem = selectedNavItemForRoute(current, sections);
    final selectedIndex = sections.indexWhere(
      (s) => s.items.any((i) => i.route == selectedItem?.route),
    );

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
                      extended: false,
                      labelType: NavigationRailLabelType.all,
                      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
                      onDestinationSelected: (i) =>
                          goToRoute(context, sections[i].items.first.route),
                      leading: Padding(
                        padding:
                        const EdgeInsets.only(top: 16.0, bottom: 16.0),
                        child: AppBrand(
                          isExtended: false,
                          companyName: companyName,
                        ),
                      ),
                      trailing: trailing ??
                          (userProfile != null
                              ? Padding(
                            padding:
                            const EdgeInsets.only(bottom: 16.0),
                            child: ProfileMini(
                              userProfile!,
                              onSwitchTenant,
                            ),
                          )
                              : null),
                      destinations: [
                        for (final section in sections)
                          NavigationRailDestination(
                            icon: BadgeIcon(
                              icon: section.destinationIcon,
                              count: _sectionBadge(section),
                            ),
                            selectedIcon: BadgeIcon(
                              icon: section.destinationIcon,
                              count: _sectionBadge(section),
                              selected: true,
                            ),
                            label: Text(section.destinationLabel),
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

  /// Wide layouts use the same labelled, grouped navigation as the drawer.
  /// This keeps operations separate from directories and system controls,
  /// instead of flattening every destination into a long rail.
  Widget _buildExpandedNavigation(
    BuildContext context,
    String current,
    List<NavSection> sections,
  ) {
    final selectedItem = selectedNavItemForRoute(current, sections);
    return SafeArea(
      child: SizedBox(
        width: 304,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: AppBrand(isExtended: true, companyName: companyName),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final section in sections)
                      DrawerSection(
                        section: section,
                        selectedItem: selectedItem,
                        badges: badges ?? const {},
                        onTap: (item) => goToRoute(context, item.route),
                      ),
                  ],
                ),
              ),
              if (userProfile != null)
                ProfileFooter(userProfile!, onSwitchTenant),
            ],
          ),
        ),
      ),
    );
  }
}
