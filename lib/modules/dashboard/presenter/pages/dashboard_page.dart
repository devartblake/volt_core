import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/shared/widgets/responsive_scaffold.dart';
import 'package:voltcore/modules/auth/auth_state.dart'; // <-- adjust path if needed

/// Role-aware dashboard:
/// - Techs see quick access to inspections & maintenance.
/// - Dispatchers / supervisors see scheduling and overviews.
/// - Admins additionally see Admin Dashboard + Admin Settings tiles.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final role = auth.currentRole;
    final isAuthed = auth.isAuthenticated;
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final greeting = _buildGreeting(auth.displayName, role);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (isAuthed && role != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                avatar: Icon(
                  _roleIcon(role),
                  size: 18,
                  color: color.onSecondaryContainer,
                ),
                label: Text(
                  _roleLabel(role),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color.onSecondaryContainer,
                  ),
                ),
                backgroundColor: color.secondaryContainer,
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          /// All possible tiles. RBAC is handled by [visibleFor].
          final tiles = _buildAllTiles(role);

          if (tiles.isEmpty) {
            // Fallback: if role has no tiles (shouldn't happen), show a message.
            return Center(
              child: Text(
                'No dashboard items available for your role.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final header = Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAuthed
                      ? 'Choose a workflow to get started.'
                      : 'Sign in to access inspections and maintenance workflows.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );

          if (isWide) {
            final crossAxisCount = (constraints.maxWidth ~/ 260).clamp(2, 4);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: GridView.builder(
                      itemCount: tiles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 4 / 3,
                      ),
                      itemBuilder: (context, index) {
                        final t = tiles[index];
                        return _DashboardTile(tile: t);
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          // Narrow layout: list
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: tiles.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return header;
              final t = tiles[index - 1];
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _DashboardTile(tile: t),
              );
            },
          );
        },
      ),
    );
  }

  String _buildGreeting(String? displayName, UserRole? role) {
    final roleLabel = role != null ? _roleLabel(role) : null;
    if (displayName != null && displayName.isNotEmpty) {
      return roleLabel != null
          ? 'Hi $displayName — $roleLabel'
          : 'Hi $displayName';
    }
    return roleLabel != null ? 'Welcome, $roleLabel' : 'Welcome';
  }
}

/// Simple tile model for the dashboard
class _DashTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Set<UserRole>? visibleFor; // null = all roles

  const _DashTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    this.visibleFor,
  });

  bool isVisibleFor(UserRole? role) {
    if (visibleFor == null) return true; // visible to all
    if (role == null) return false;
    return visibleFor!.contains(role);
  }
}

/// Build all dashboard tiles (RBAC-aware)
List<_DashTile> _buildAllTiles(UserRole? role) {
  const all = <_DashTile>[
    // --- Core tech workflows ---
    _DashTile(
      title: 'New Inspection',
      subtitle: 'Start a generator compliance inspection',
      icon: Icons.fact_check_outlined,
      routeName: 'inspection_new',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Inspection History',
      subtitle: 'View previous inspections & reports',
      icon: Icons.history_outlined,
      routeName: 'inspections',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'New Maintenance Job',
      subtitle: 'Create a maintenance / repair checklist',
      icon: Icons.build_circle_outlined,
      routeName: 'maintenance_new',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Maintenance Archive',
      subtitle: 'Browse and export maintenance history',
      icon: Icons.archive_outlined,
      routeName: 'maintenance_archive',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Schedule',
      subtitle: 'View inspection & maintenance calendar',
      icon: Icons.calendar_month_outlined,
      routeName: 'schedule',
      visibleFor: {
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),

    // --- Equipment / nameplates ---
    _DashTile(
      title: 'Equipment Registry',
      subtitle: 'Manage generator nameplate infra',
      icon: Icons.inventory_2_outlined,
      routeName: 'nameplate_list',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),

    // --- Admin-only entries ---
    _DashTile(
      title: 'Admin Dashboard',
      subtitle: 'Fleet analytics, KPIs & overview',
      icon: Icons.analytics_outlined,
      routeName: 'admin_dashboard', // <-- make sure this route exists
      visibleFor: {
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Admin Settings',
      subtitle: 'Roles, permissions & configuration',
      icon: Icons.admin_panel_settings_outlined,
      routeName: 'admin_settings', // <-- make sure this route exists
      visibleFor: {
        UserRole.admin,
      },
    ),
  ];

  // If no role yet (e.g. not logged in), only show tiles that don't require a role.
  if (role == null) {
    // For now we hide everything that requires a role.
    // If you want some public tiles, set visibleFor: null on them.
    return all.where((t) => t.visibleFor == null).toList();
  }

  return all.where((t) => t.isVisibleFor(role)).toList();
}

/// Single dashboard tile widget.
class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.tile});

  final _DashTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: () => context.goNamed(tile.routeName),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tile.icon,
                  size: 28,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tile.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper: human label for roles
String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.tech:
      return 'Technician';
    case UserRole.dispatcher:
      return 'Dispatcher';
    case UserRole.supervisor:
      return 'Supervisor';
    case UserRole.admin:
      return 'Admin';
  }
}

/// Helper: icon for roles
IconData _roleIcon(UserRole role) {
  switch (role) {
    case UserRole.tech:
      return Icons.engineering_outlined;
    case UserRole.dispatcher:
      return Icons.support_agent_outlined;
    case UserRole.supervisor:
      return Icons.verified_user_outlined;
    case UserRole.admin:
      return Icons.admin_panel_settings_outlined;
  }
}
