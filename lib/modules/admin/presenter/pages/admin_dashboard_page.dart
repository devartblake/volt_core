import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/modules/admin/presenter/controllers/admin_dashboard_controller.dart';

/// Admin dashboard with basic system overview + live "Active Technicians" count.
///
/// Visually it's the same layout you had:
/// - Header
/// - Description
/// - Three stat cards
///
/// The only functional change is that "Active Technicians" now uses the
/// AdminDashboardController to show a real count when available.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final stats = state.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'System Overview',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'High-level overview of inspections, maintenance, and your technician team. '
                  'Use the tiles below to drill into details or manage roles.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Loading / error indicators
            if (state.isLoading && stats == null) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 8),

            // Top stat cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'Total Inspections',
                  value: stats?.totalInspections.toString() ?? '—',
                  icon: Icons.fact_check_outlined,
                  color: colorScheme.primary,
                ),
                _StatCard(
                  label: 'Open Maintenance Jobs',
                  value: stats?.openMaintenanceJobs.toString() ?? '—',
                  icon: Icons.build_outlined,
                  color: colorScheme.tertiary,
                ),
                _StatCard(
                  label: 'Active Technicians',
                  value: stats?.activeTechnicians.toString() ?? '—',
                  icon: Icons.engineering_outlined,
                  color: colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 32),

            _NavCard(
              icon: Icons.engineering_outlined,
              title: 'Manage Technicians & Roles',
              subtitle:
              'View all technicians, change their roles, and keep your RBAC clean.',
              color: colorScheme.primaryContainer,
              onTap: () {
                context.go('/admin/technicians');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 260,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme
        .of(context)
        .textTheme;
    final cs = Theme
        .of(context)
        .colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
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
