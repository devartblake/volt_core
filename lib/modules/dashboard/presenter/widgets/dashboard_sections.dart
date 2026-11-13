import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../schedule/domain/entities/task_schedule_entity.dart';
import '../../domain/dashboard_summary.dart';
import '../../domain/technician_day.dart';

/// Tappable stand-in for a search field: opens the global search screen.
class DashboardSearchBar extends StatelessWidget {
  const DashboardSearchBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Search pages, inspections, jobs, vehicles and customers',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          borderRadius: AppRadius.pillAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search inspections, jobs, vehicles, customers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block of the dashboard.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  ExcludeSemantics(
                    child: Icon(icon, size: 20, color: scheme.primary),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// What needs a look right now, or a calm "all clear".
class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<AttentionItem> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = theme.status;

    Color colorFor(AttentionSeverity s) => switch (s) {
          AttentionSeverity.critical => theme.colorScheme.error,
          AttentionSeverity.warning => status.warning,
          AttentionSeverity.info => status.info,
        };

    return DashboardCard(
      title: 'Needs attention',
      icon: Icons.notifications_active_outlined,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: status.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All clear - nothing overdue or waiting on you.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 8,
                    leading: Icon(item.icon, color: colorFor(item.severity)),
                    title: Text(
                      item.label,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(item.detail),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(item.route),
                  ),
              ],
            ),
    );
  }
}

String _timeLabel(DateTime d) {
  final l = d.toLocal();
  final h = l.hour == 0 ? 12 : (l.hour > 12 ? l.hour - 12 : l.hour);
  final m = l.minute.toString().padLeft(2, '0');
  return '$h:$m ${l.hour >= 12 ? 'PM' : 'AM'}';
}

StatusTone _toneFor(String status) => switch (status) {
      'completed' => StatusTone.success,
      'cancelled' => StatusTone.danger,
      'in_progress' => StatusTone.info,
      'overdue' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

String _statusLabel(String status) => switch (status) {
      'in_progress' => 'In progress',
      'scheduled' => 'Scheduled',
      'completed' => 'Done',
      'pending' => 'Pending',
      'overdue' => 'Overdue',
      _ => status.isEmpty
          ? 'Scheduled'
          : '${status[0].toUpperCase()}${status.substring(1)}',
    };

/// Today's tasks in time order.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.summary,
    required this.onOpenTask,
    required this.onOpenSchedule,
    this.maxRows = 6,
  });

  final DashboardSummary summary;
  final ValueChanged<TaskScheduleEntity> onOpenTask;
  final VoidCallback onOpenSchedule;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = summary.today.take(maxRows).toList();
    final hidden = summary.today.length - shown.length;

    return DashboardCard(
      title: 'Today',
      icon: Icons.today_outlined,
      trailing: TextButton(
        onPressed: onOpenSchedule,
        child: const Text('Schedule'),
      ),
      child: summary.today.isEmpty
          ? const EmptyState(
              compact: true,
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled today',
              message: 'Tasks you schedule for today will show up here.',
            )
          : Column(
              children: [
                for (final task in shown)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 8,
                    onTap: () => onOpenTask(task),
                    leading: SizedBox(
                      width: 68,
                      child: Text(
                        _timeLabel(task.scheduledAt),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      task.address.isEmpty
                          ? (task.title.isEmpty ? 'Scheduled task' : task.title)
                          : task.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: task.title.isNotEmpty && task.address.isNotEmpty
                        ? Text(task.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: StatusChip(
                      label: _statusLabel(task.status),
                      tone: _toneFor(task.status),
                    ),
                  ),
                if (hidden > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onOpenSchedule,
                      child: Text('and $hidden more'),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One shortcut on the dashboard.
@immutable
class DashboardAction {
  const DashboardAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.routeName,
    this.audiences,
  });

  final String label;
  final IconData icon;
  final String route;

  /// For the role check.
  final String routeName;

  /// Roles this shortcut leads for; null means everyone allowed to open it.
  final Set<DashboardAudience>? audiences;
}

/// Shortcut tiles in a responsive grid.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.actions,
    required this.onOpen,
  });

  final List<DashboardAction> actions;
  final ValueChanged<DashboardAction> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 3
                : 2;
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        final extent = 92.0 * scale.clamp(1.0, 1.6);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, i) {
            final a = actions[i];
            return Material(
              color: scheme.secondaryContainer.withValues(alpha: 0.45),
              borderRadius: AppRadius.cardAll,
              child: InkWell(
                borderRadius: AppRadius.cardAll,
                onTap: () => onOpen(a),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ExcludeSemantics(
                        child: Icon(a.icon, color: scheme.primary),
                      ),
                      Text(
                        a.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Placeholder layout while the schedule loads for the first time.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard',
      child: const Column(
        children: [
          Row(children: [
            Expanded(child: Skeleton.card(height: 120)),
            SizedBox(width: 12),
            Expanded(child: Skeleton.card(height: 120)),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: Skeleton.card(height: 120)),
            SizedBox(width: 12),
            Expanded(child: Skeleton.card(height: 120)),
          ]),
          SizedBox(height: 16),
          Skeleton.card(height: 180),
          SizedBox(height: 16),
          Skeleton.card(height: 140),
        ],
      ),
    );
  }
}

/// Dispatcher view: one row per technician with today's task count and when
/// their next open task starts. Tasks with nobody assigned sit under
/// "Unassigned".
class TechnicianDaysCard extends StatelessWidget {
  const TechnicianDaysCard({
    super.key,
    required this.days,
    required this.onOpen,
    this.divisionLabels = const {},
  });

  final List<TechnicianDay> days;

  /// Optional division label per user id, shown as a second subtitle line.
  final Map<String, String> divisionLabels;

  /// Opens the schedule (for a technician, or the unassigned pool).
  final ValueChanged<TechnicianDay> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: 'Who is on what today',
      icon: Icons.groups_outlined,
      child: days.isEmpty
          ? const EmptyState(
              compact: true,
              icon: Icons.groups_outlined,
              title: 'No one is scheduled today',
              message: 'Technicians and their tasks for today show up here.',
            )
          : Column(
              children: [
                for (final d in days)
                  ListTile(
                    key: Key('tech_day_${d.userId ?? 'unassigned'}'),
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 8,
                    onTap: () => onOpen(d),
                    leading: CircleAvatar(
                      backgroundColor: d.isUnassigned
                          ? scheme.tertiaryContainer
                          : scheme.primaryContainer,
                      foregroundColor: d.isUnassigned
                          ? scheme.onTertiaryContainer
                          : scheme.onPrimaryContainer,
                      child: Icon(
                        d.isUnassigned
                            ? Icons.person_off_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(d.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.count == 0
                              ? 'Nothing today'
                              : d.nextTaskAt == null
                                  ? 'All done'
                                  : 'Next at ${_timeLabel(d.nextTaskAt!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((divisionLabels[d.userId] ?? '').isNotEmpty)
                          Text(
                            divisionLabels[d.userId]!,
                            key: Key('tech_day_divisions_${d.userId}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: StatusChip(
                      label: d.count == 1 ? '1 task' : '${d.count} tasks',
                      tone: d.isUnassigned && d.count > 0
                          ? StatusTone.warning
                          : (d.count == 0
                              ? StatusTone.neutral
                              : StatusTone.info),
                    ),
                  ),
              ],
            ),
    );
  }
}
