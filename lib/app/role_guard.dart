import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/pages/forbidden_page.dart';

import '../core/ui/forbidden_page.dart';
import '../modules/auth/auth_state.dart';

/// Simple widget guard for role-based access.
///
/// You can wrap any page in this widget if you want to guard it locally,
/// for example:
///
///   GoRoute(
///     path: '/admin',
///     name: 'admin_dashboard',
///     builder: (_, __) => const RoleGuard(
///       routeName: 'admin_dashboard',
///       child: AdminDashboardPage(),
///     ),
///   );
///
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.routeName,
    required this.child,
  });

  final String routeName;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final UserRole? role = auth.currentRole;

    final allowed = RouteRoles.isAllowedByName(
      name: routeName,
      role: role,
    );

    if (!allowed) {
      return const ForbiddenPage();
    }

    return child;
  }
}