import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltcore/app/app_drawer.dart';

import '../core/services/tenants/tenants_service.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/auth/state/auth_state.dart';
import '../shared/presenter/widgets/sync_status_indicator.dart';

/// Generic shell that wraps a page with AppDrawer + responsive layout.
///
/// - On narrow screens: uses a Scaffold with a Drawer.
/// - On wide screens: shows NavigationRail (from AppDrawer) on the left,
///   and your page content on the right.
/// - It also builds an AppUserProfile from the current AuthState so the
///   drawer shows user info + (future) tenant switching.
class DefaultShell extends ConsumerWidget {
  const DefaultShell({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    // Real tenants, fetched at login and cached in Hive by TenantsService.
    // While the service is loading (or if it fails) we fall back to no tenant
    // rather than inventing a name.
    final tenants = ref.watch(tenantsProvider);
    final profile = _buildProfileFromAuth(auth, tenants);

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 800; // keep in sync with kCompactBreakpoint

    if (isCompact) {
      // Mobile / narrow → Drawer pattern
      return Scaffold(
        appBar: AppBar(
          title: Text(title ?? 'Voltcore'),
          actions: const [SyncStatusIndicator(), SizedBox(width: 4)],
        ),
        drawer: AppDrawer(
          userProfile: profile,
        ),
        body: child,
      );
    }

    // Wide screens → NavigationRail on the left, content on the right.
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Voltcore'),
        actions: const [SyncStatusIndicator(), SizedBox(width: 8)],
      ),
      body: Row(
        children: [
          // AppDrawer will render as a NavigationRail + divider
          AppDrawer(
            userProfile: profile,
          ),
          // Main content
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Shell used for *technician / field* flows.
/// Right now it just changes the title, but you can
/// add tech-specific app bar actions later.
class TechShell extends ConsumerWidget {
  const TechShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultShell(
      title: 'Voltcore — Technician',
      child: child,
    );
  }
}

/// Shell used for *admin / supervisor / dispatcher* flows.
/// Again, mostly a semantic wrapper around DefaultShell
/// so your AppRouter can be explicit about intent.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultShell(
      title: 'Voltcore — Admin',
      child: child,
    );
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
