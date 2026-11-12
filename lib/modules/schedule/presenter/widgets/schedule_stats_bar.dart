import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../domain/entities/task_schedule_entity.dart';

/// Three counters above the schedule: tasks in range, upcoming, completed
/// (dated in the past).
class ScheduleStatsBar extends StatelessWidget {
  const ScheduleStatsBar({
    super.key,
    required this.rangeLabel,
    required this.items,
  });

  final String rangeLabel;
  final List<TaskScheduleEntity> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final upcoming = items.where((i) => i.scheduledDate.isAfter(now)).length;
    final past = items.where((i) => i.scheduledDate.isBefore(now)).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsChip(
              icon: Icons.event_available,
              label: rangeLabel,
              value: '${items.length}',
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatsChip(
              icon: Icons.pending_actions,
              label: 'Upcoming',
              value: '$upcoming',
              color: theme.status.info,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatsChip(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: '$past',
              color: theme.status.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  const _StatsChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.fieldAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
