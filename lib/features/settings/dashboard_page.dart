import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/shared/widgets/responsive_scaffold.dart';

/// DASHBOARD – Home screen for the app.
/// This replaces SelectionOptionsPage and should be used as your root route.
///
/// You will register this in AppRouter as the initial location, e.g.
/// GoRoute(
///   path: '/',
///   name: 'dashboard',
///   builder: (_, __) => const DashboardPage(),
/// );
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('A&S Electric – Dashboard'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          const padding = EdgeInsets.all(16.0);

          if (isWide) {
            final crossAxisCount = constraints.maxWidth ~/ 260;
            return Padding(
              padding: padding,
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  crossAxisCount: crossAxisCount.clamp(2, 4),
                  childAspectRatio: 4 / 3,
                ),
                itemBuilder: (context, index) {
                  final opt = options[index];
                  return _DashboardCard(
                    option: opt,
                    theme: theme,
                    onTap: () => _onOptionTap(context, opt),
                  );
                },
              ),
            );
          }

          /// Narrow-screen layout: list view (phones)
          return ListView.separated(
            padding: padding,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final opt = options[index];
              return _DashboardCard(
                option: opt,
                theme: theme,
                onTap: () => _onOptionTap(context, opt),
              );
            },
          );
        },
      ),
    );
  }

  void _onOptionTap(BuildContext context, _DashboardOption opt) {
    if (opt.routeName != null) {
      context.goNamed(opt.routeName!);
    } else if (opt.routePath != null) {
      context.go(opt.routePath!);
    }
  }
}

/// Internal model (unchanged)
class _DashboardOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? routeName;
  final String? routePath;

  const _DashboardOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.routeName,
    this.routePath,
  });
}

/// Dashboard options – update routeName/path to match your AppRouter.
const List<_DashboardOption> _options = [
  _DashboardOption(
    title: 'Generator Inspection',
    subtitle: 'Full compliance & load test form',
    icon: Icons.fact_check_outlined,
    routeName: 'inspection_new',
  ),
  _DashboardOption(
    title: 'Maintenance Service',
    subtitle: 'Maintenance & repair checklist',
    icon: Icons.build_circle_outlined,
    routeName: 'maintenance_new',
  ),
  _DashboardOption(
    title: 'Maintenance Archive',
    subtitle: 'View previous maintenance reports',
    icon: Icons.archive_outlined,
    routeName: 'maintenance_archive',
  ),
  _DashboardOption(
    title: 'Nameplate List',
    subtitle: 'View or edit generator nameplate data',
    icon: Icons.list_alt_outlined,
    routeName: 'nameplate_list',
  ),
  _DashboardOption(
    title: 'Equipment Search',
    subtitle: 'Find equipment by name, make, or serial',
    icon: Icons.search,
    routeName: 'equipment_search',
  ),
  _DashboardOption(
    title: 'Schedule',
    subtitle: 'View inspection and maintenance schedule',
    icon: Icons.calendar_month_outlined,
    routeName: 'schedule',
  ),
];

/// Card widget used in grid and list (unchanged)
class _DashboardCard extends StatelessWidget {
  final _DashboardOption option;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.option,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.08),
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
                  option.icon,
                  color: colors.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
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