import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/schedule_view_logic.dart';
import '../schedule_navigation.dart';
import 'schedule_status.dart';

/// The one schedule card, shared by the list, day and week views.
///
/// Shows time, title, site, assigned technician and status. When [onAssign]
/// is set (dispatchers and above) an Assign / Reassign button is shown.
class ScheduleJobCard extends StatelessWidget {
  const ScheduleJobCard({
    super.key,
    required this.item,
    this.assigneeName,
    this.showDate = false,
    this.onAssign,
    this.onTap,
  });

  final TaskScheduleEntity item;

  /// Name of the assigned technician; null renders "Unassigned".
  final String? assigneeName;

  /// Also show the date (for views that do not group by day).
  final bool showDate;

  final VoidCallback? onAssign;

  /// Defaults to opening the task detail.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = dateOnly(item.scheduledAt) == dateOnly(DateTime.now());
    final title = item.address.isEmpty
        ? (item.title.isEmpty ? '(No address/title)' : item.title)
        : item.address;
    final unassigned = assigneeName == null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(
          color: isToday ? scheme.primary : scheme.outlineVariant,
          width: isToday ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => openScheduledTask(context, item),
        borderRadius: AppRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 64),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: AppRadius.fieldAll,
                    ),
                    child: Text(
                      formatScheduleTime(item.scheduledAt),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.address.isNotEmpty && item.title.isNotEmpty)
                          Text(
                            item.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ScheduleStatusChip(status: item.status),
                  if (showDate)
                    InfoChip(
                      icon: Icons.calendar_today,
                      label: formatShortDate(item.scheduledAt),
                    ),
                  if (item.siteCode.isNotEmpty)
                    InfoChip(
                      icon: Icons.location_on_outlined,
                      label: item.siteCode,
                    ),
                  if (item.siteGrade.isNotEmpty) _GradeChip(grade: item.siteGrade),
                  InfoChip(
                    icon: unassigned
                        ? Icons.person_off_outlined
                        : Icons.person_outline,
                    label: assigneeName ?? 'Unassigned',
                    emphasized: unassigned,
                  ),
                ],
              ),
              if (onAssign != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(unassigned ? 'Assign' : 'Reassign'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.gradeColor(grade, fallback: theme.colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.chipAll,
      ),
      child: Text(
        grade,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
