import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltcore/app/app_drawer.dart';

import '../core/services/tenants/tenants_service.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/auth/state/auth_state.dart';
import '../shared/widgets/app_page.dart';

/// Generic shell that wraps a page with navigation + responsive layout.
///
/// - On narrow screens: publishes an [AppDrawer] for the page's Scaffold.
/// - On wide screens: shows the NavigationRail (from AppDrawer) on the left,
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
    final auth = ref.watch(authStateProvider);

    // Real tenants, fetched at login and cached in Hive by TenantsService.
    // While the service is loading (or if it fails) we fall back to no tenant
    // rather than inventing a name.
    final tenants = ref.watch(tenantsProvider);
    final profile = _buildProfileFromAuth(auth, tenants);

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < kCompactBreakpoint;

    // The shell owns *navigation only*. The page inside builds the single
    // Scaffold + AppBar via AppPage, using the drawer published here — that is
    // what keeps one header (and one drawer) per screen.
    if (isCompact) {
      return AppShellScope(
        isCompact: true,
        drawer: AppDrawer(userProfile: profile),
        child: child,
      );
    }

    // Wide screens → persistent NavigationRail beside the page.
    return AppShellScope(
      isCompact: false,
      drawer: null,
      child: Row(
        children: [
          // AppDrawer renders as a NavigationRail + divider at this width.
          AppDrawer(userProfile: profile),
          Expanded(child: child),
        ],
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
