import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../modules/auth/auth_state.dart';
import 'route_roles.dart';
import '../core/presenter/forbidden_page.dart';

/// Wrap any page in [RoleGuard] if you want widget-level protection.
///
/// In your routes:
///   builder: (_, __) => const RoleGuard(
///     path: '/inspections',
///     child: InspectionListPage(),
///   ),
class RoleGuard extends ConsumerWidget {
  final String path;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.path,
    required this.child,
    required Set<UserRole> allowedRoles,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    if (!auth.isAuthenticated) {
      // If you want a different behavior you can navigate to /login instead.
      return const ForbiddenPage(
        title: 'Not signed in',
        message: 'Please sign in to access this section.',
      );
    }

    if (!RouteRoles.isAllowed(path: path, role: auth.currentRole)) {
      return const ForbiddenPage(
        title: 'Access denied',
        message: 'You don’t have permission to view this page.',
      );
    }

    return child;
  }
}