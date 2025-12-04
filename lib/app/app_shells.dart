import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltcore/app/app_drawer.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

import '../modules/auth/presenter/controllers/auth_controller.dart';
import '../modules/auth/state/auth_state.dart';

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
    final profile = _buildProfileFromAuth(auth);

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 800; // keep in sync with kCompactBreakpoint

    if (isCompact) {
      // Mobile / narrow → Drawer pattern
      return Scaffold(
        appBar: AppBar(
          title: Text(title ?? 'Voltcore'),
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

/// Helper that maps AuthState → AppUserProfile used by AppDrawer.
///
/// We intentionally keep this minimal so it doesn’t introduce new
/// fields on AuthState beyond what you already have.
AppUserProfile? _buildProfileFromAuth(AuthState auth) {
  if (!auth.isAuthenticated) return null;

  // We assume AuthState has: email, displayName, currentRole.
  // These were part of the previous RBAC/auth patches.
  final displayName = auth.displayName ?? auth.email ?? 'User';
  final email = auth.email ?? 'unknown@example.com';

  // For now, single-tenant placeholder. You can later wire this
  // to real tenant data without touching AppDrawer.
  const tenantName = 'Default Site';

  return AppUserProfile(
    displayName: displayName,
    email: email,
    avatarUrl: null,
    currentTenant: tenantName,
    tenants: const [tenantName],
    role: auth.currentRole?.name, // e.g. 'tech', 'admin'
  );
}
