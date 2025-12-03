import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infra/models/inspection.dart' as model;
import '../../infra/repositories/inspection_repo.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/app_badges_provider.dart';

class InspectionListPage extends ConsumerWidget {
  final String? filterStatus;
  const InspectionListPage({super.key, this.filterStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.read(inspectionRepoProvider).listAll();
    final theme = Theme.of(context);

    // apply filter if provided
    final items = filterStatus != null
        ? allItems.where((i) => i.siteGrade.toLowerCase() == filterStatus!.toLowerCase()).toList()
        : allItems;

    // Watch providers for reactive updates
    final badges = ref.watch(appBadgesProvider);
    final userProfile = ref.watch(userProfileProvider);
    final currentTenant = ref.watch(currentTenantProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Inspections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Implement edit mode (multi-select, delete, etc.)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit mode - Coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern stats cards showing badge information
          if (items.isNotEmpty) _buildStatsSection(context, theme, badges),

          // Main content
          Expanded(
            child: items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No inspections yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create your first inspection',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (_, i) => _modernTile(context, theme, items[i]),
            ),
          ),
        ],
      ),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
      badges: badges.toRouteMap(),
      userProfile: userProfile,
      onSwitchTenant: (tenant) {
        ref.read(currentTenantProvider.notifier).switchTenant(tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to $tenant')),
        );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context, ThemeData theme, AppBadges badges) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.list_alt,
              label: 'Total',
              count: badges.totalInspections,
              color: theme.colorScheme.primary,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.pending_actions,
              label: 'Pending',
              count: badges.pendingInspections,
              color: Colors.blue,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.warning_amber_rounded,
              label: 'Amber',
              count: badges.amberGradeInspections,
              color: Colors.orange,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.error_outline,
              label: 'Red',
              count: badges.redGradeInspections,
              color: Colors.red,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernTile(BuildContext ctx, ThemeData theme, model.Inspection ins) {
    final dateStr = ins.serviceDate.toIso8601String().split("T").first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => GoRouter.of(ctx).push('/detail/${ins.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getGradeColor(ins.siteGrade, theme).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_input_antenna,
                  color: _getGradeColor(ins.siteGrade, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ins.address.isEmpty ? '(No address)' : ins.address,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.calendar_today,
                          label: dateStr,
                          theme: theme,
                        ),
                        if (ins.siteCode.isNotEmpty)
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            label: ins.siteCode,
                            theme: theme,
                          ),
                        if (ins.siteGrade.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(ins.siteGrade, theme)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ins.siteGrade,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getGradeColor(ins.siteGrade, theme),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade, ThemeData theme) {
    switch (grade.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Modern stat card for displaying metrics
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}