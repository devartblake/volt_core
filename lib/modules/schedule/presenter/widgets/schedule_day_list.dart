import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/schedule_view_logic.dart';
import 'schedule_job_card.dart';

/// Tasks grouped by day with a date header, each day in time order. Used by
/// the list, Day and Week views.
class ScheduleDayList extends StatelessWidget {
  const ScheduleDayList({
    super.key,
    required this.tasks,
    required this.names,
    this.onAssign,
    this.emptyTitle = 'No inspections found',
    this.emptyMessage = 'Try adjusting your filter',
  });

  final List<TaskScheduleEntity> tasks;

  /// User id -> display name.
  final Map<String, String> names;

  /// Set when the viewer may assign; shows the button on each card.
  final ValueChanged<TaskScheduleEntity>? onAssign;

  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = groupTasksByDay(tasks).entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final date = groups[index].key;
        final dayItems = groups[index].value;
        final isToday = date == dateOnly(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md),
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.chipAll,
                      ),
                      child: Text(
                        formatDayHeader(date),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isToday
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${dayItems.length} inspection${dayItems.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in dayItems)
              ScheduleJobCard(
                item: item,
                assigneeName: assigneeLabel(item, names),
                onAssign: onAssign == null ? null : () => onAssign!(item),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }
}
