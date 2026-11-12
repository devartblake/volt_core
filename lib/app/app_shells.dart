import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltcore/app/app_drawer.dart';

import 'app_bottom_nav.dart';
import 'nav_style_provider.dart';
import '../modules/search/presenter/global_search.dart';

import '../core/services/tenants/tenants_service.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/auth/state/auth_state.dart';
import '../shared/widgets/app_page.dart';

/// Generic shell that wraps a page with navigation + responsive layout.
///
/// - On narrow screens: publishes an [AppDrawer] for the page's Scaffold.
/// - On wide screens: shows grouped persistent navigation on the left,
///   with the page content on the right.
/// - It builds an AppUserProfile from the current AuthState so the drawer shows
///   user info, the active tenant, and role.
///
/// The shell deliberately renders **no AppBar** — the page does, via [AppPage].
/// Both drawing one is what produced the doubled headers this replaced.
class DefaultShell extends ConsumerWidget {
  const DefaultShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SearchShortcut(child: _buildShell(context, ref));
  }

  Widget _buildShell(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    // Real tenants, fetched at login and cached in Hive by TenantsService.
    // While the service is loading (or if it fails) we fall back to no tenant
    // rather than inventing a name.
    final tenants = ref.watch(tenantsProvider);
    final profile = _buildProfileFromAuth(auth, tenants);

    final size = MediaQuery.sizeOf(context);
    final isCompact = isCompactLayout(size);
    final navStyle = ref.watch(navStyleProvider);
    final bottomOnTablet = !isCompact && navStyle == NavStyle.bottom;

    final role = auth.currentRole;
    final location = currentNavLocation(context);
    final sections = navSectionsForRole(role);

    // The other pages of the section being viewed, shown as tabs under the
    // page's app bar. The full-width sidebar already lists every page, so tabs
    // would only repeat it there.
    // Only on a section's own pages: a detail or form screen has its own back
    // arrow and does not need links to its siblings.
    final nav = AppBottomNav.isTopLevel(sections, location)
        ? sectionNavFor(role, location)
        : null;
    final sidebarShown = !isCompact && !bottomOnTablet && size.width >= kExpandedBreakpoint;
    final tabs = [
      if (nav != null && !sidebarShown)
        for (final item in nav.items)
          SectionTab(
            label: item.label,
            icon: item.icon,
            route: item.route,
            selected: item.route == nav.selected?.route,
          ),
    ];

    // Bottom navigation: on phones always (with "More" opening the drawer), on
    // tablets when chosen in Settings. Top-level pages only; detail and form
    // screens keep their back arrow.
    final Widget? bottomNav =
        (isCompact || bottomOnTablet) && AppBottomNav.isTopLevel(sections, location)
            ? AppBottomNav(
                sections: sections,
                location: location,
                maxDestinations: isCompact ? 5 : 8,
                showMore: isCompact,
              )
            : null;

    // The shell owns *navigation only*. The page inside builds the single
    // Scaffold + AppBar via AppPage, using the drawer published here — that is
    // what keeps one header (and one drawer) per screen.
    if (isCompact) {
      return AppShellScope(
        isCompact: true,
        drawer: AppDrawer(userProfile: profile),
        sectionTabs: tabs,
        bottomNav: bottomNav,
        onSearch: () => showGlobalSearch(context),
        child: child,
      );
    }

    // Tablet with the bottom-bar style: no rail, the bar carries navigation.
    if (bottomOnTablet) {
      return AppShellScope(
        isCompact: false,
        drawer: null,
        sectionTabs: tabs,
        bottomNav: bottomNav,
        onSearch: () => showGlobalSearch(context),
        child: child,
      );
    }

    // Wide screens → persistent grouped navigation beside the page.
    return AppShellScope(
      isCompact: false,
      drawer: null,
      sectionTabs: tabs,
      onSearch: () => showGlobalSearch(context),
      child: Row(
        children: [
          // AppDrawer renders as a grouped navigation sidebar at this width.
          AppDrawer(userProfile: profile),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Ctrl+K (Cmd+K on macOS) opens global search from anywhere in the shell, for
/// devices with a hardware keyboard.
class SearchShortcut extends StatelessWidget {
  const SearchShortcut({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    void open() => showGlobalSearch(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): open,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): open,
      },
      // Takes focus only when nothing else has it; fields keep theirs and the
      // key press bubbles up to here.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: child,
      ),
    );
  }
}

/// Shell used for *technician / field* flows.
///
/// A semantic wrapper so the router can be explicit about intent. Navigation
/// itself is already role-filtered inside [AppDrawer]; giving the shells
/// genuinely different surfaces is Phase 3c.
class TechShell extends ConsumerWidget {
  const TechShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultShell(child: child);
  }
}

/// Shell used for *admin / supervisor / dispatcher* flows.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultShell(child: child);
  }
}

/// Tenant names for the signed-in user plus the active one.
///
/// Sourced from [TenantsService], which `AuthController.login` populates from
/// `tenant_members` and caches in Hive so it survives restarts and offline use.
@immutable
class TenantSelection {
  const TenantSelection({this.current, this.available = const []});

  final String? current;
  final List<String> available;

  static const TenantSelection empty = TenantSelection();
}

final tenantsProvider = Provider<TenantSelection>((ref) {
  final service = ref.watch(tenantsServiceProvider);

  return service.maybeWhen(
    data: (svc) {
      final available = svc.getTenants();
      final current = svc.getCurrentTenant() ??
          (available.isNotEmpty ? available.first : null);
      return TenantSelection(current: current, available: available);
    },
    orElse: () => TenantSelection.empty,
  );
});

/// Helper that maps AuthState (+ tenants) → AppUserProfile used by AppDrawer.
AppUserProfile? _buildProfileFromAuth(
  AuthState auth,
  TenantSelection tenants,
) {
  if (!auth.isAuthenticated) return null;

  final displayName = auth.displayName ?? auth.email ?? 'User';
  final email = auth.email ?? 'unknown@example.com';

  return AppUserProfile(
    displayName: displayName,
    email: email,
    avatarUrl: null,
    currentTenant: tenants.current,
    tenants: tenants.available,
    role: auth.currentRole?.name, // e.g. 'tech', 'admin'
  );
}
