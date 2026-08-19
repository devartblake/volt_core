import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../core/services/hive/hive_boxes.dart';
import '../../../maintenance/infra/datasources/hive_boxes_maintenance.dart';
import '../../../maintenance/infra/models/maintenance_record.dart';
import '../../../schedule/infra/datasources/scheduled_tasks_box.dart';
import '../../../schedule/infra/models/schedule_task.dart';

/// Analytics overview computed from local Hive data: inspection volume and site
/// grades, maintenance completion, and schedule health. Offline-friendly — it
/// reads whatever is on device.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  _Metrics _metrics = const _Metrics.empty();

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    setState(() => _metrics = _Metrics.fromBoxes());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _metrics;

    return AppPage(
      title: 'Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _compute,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => _compute(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Inspections', theme: theme),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'Total inspections',
                  value: '${m.totalInspections}',
                  icon: Icons.fact_check_outlined,
                  color: theme.colorScheme.primary,
                ),
                _StatCard(
                  label: 'With deficiencies',
                  value: '${m.deficiencies}',
                  icon: Icons.report_problem_outlined,
                  color: Colors.orange,
                ),
                _StatCard(
                  label: 'Load tests done',
                  value: '${m.loadTestsDone}',
                  icon: Icons.speed_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                _StatCard(
                  label: 'This month',
                  value: '${m.inspectionsThisMonth}',
                  icon: Icons.calendar_today_outlined,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GradeBreakdown(
              green: m.green,
              amber: m.amber,
              red: m.red,
              ungraded: m.ungraded,
              theme: theme,
            ),
            const SizedBox(height: 24),

            _SectionLabel('Maintenance', theme: theme),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'Total jobs',
                  value: '${m.totalMaintenance}',
                  icon: Icons.build_outlined,
                  color: theme.colorScheme.primary,
                ),
                _StatCard(
                  label: 'Completed',
                  value: '${m.maintenanceCompleted}',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _StatCard(
                  label: 'Open',
                  value: '${m.maintenanceOpen}',
                  icon: Icons.pending_actions_outlined,
                  color: theme.colorScheme.secondary,
                ),
                _StatCard(
                  label: 'Needs follow-up',
                  value: '${m.maintenanceFollowUp}',
                  icon: Icons.flag_outlined,
                  color: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressCard(
              label: 'Maintenance completion',
              done: m.maintenanceCompleted,
              total: m.totalMaintenance,
              theme: theme,
            ),
            const SizedBox(height: 24),

            _SectionLabel('Schedule', theme: theme),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'Upcoming',
                  value: '${m.upcomingTasks}',
                  icon: Icons.event_available_outlined,
                  color: theme.colorScheme.primary,
                ),
                _StatCard(
                  label: 'Overdue',
                  value: '${m.overdueTasks}',
                  icon: Icons.event_busy_outlined,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Aggregated, immutable metrics snapshot.
class _Metrics {
  const _Metrics({
    required this.totalInspections,
    required this.green,
    required this.amber,
    required this.red,
    required this.ungraded,
    required this.deficiencies,
    required this.loadTestsDone,
    required this.inspectionsThisMonth,
    required this.totalMaintenance,
    required this.maintenanceCompleted,
    required this.maintenanceOpen,
    required this.maintenanceFollowUp,
    required this.upcomingTasks,
    required this.overdueTasks,
  });

  const _Metrics.empty()
      : totalInspections = 0,
        green = 0,
        amber = 0,
        red = 0,
        ungraded = 0,
        deficiencies = 0,
        loadTestsDone = 0,
        inspectionsThisMonth = 0,
        totalMaintenance = 0,
        maintenanceCompleted = 0,
        maintenanceOpen = 0,
        maintenanceFollowUp = 0,
        upcomingTasks = 0,
        overdueTasks = 0;

  final int totalInspections;
  final int green;
  final int amber;
  final int red;
  final int ungraded;
  final int deficiencies;
  final int loadTestsDone;
  final int inspectionsThisMonth;
  final int totalMaintenance;
  final int maintenanceCompleted;
  final int maintenanceOpen;
  final int maintenanceFollowUp;
  final int upcomingTasks;
  final int overdueTasks;

  factory _Metrics.fromBoxes() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    // Inspections
    final inspections =
        Hive.isBoxOpen(HiveBoxes.inspectionsBoxName) ? HiveBoxes.inspections.values.toList() : const [];
    var green = 0, amber = 0, red = 0, ungraded = 0, deficiencies = 0;
    var loadTestsDone = 0, thisMonth = 0;
    for (final ins in inspections) {
      switch (ins.siteGrade) {
        case 'Green':
          green++;
          break;
        case 'Amber':
          amber++;
          break;
        case 'Red':
          red++;
          break;
        default:
          ungraded++;
      }
      if (ins.deficienciesDocumented) deficiencies++;
      if (ins.loadbankDone) loadTestsDone++;
      if (!ins.createdAt.isBefore(monthStart)) thisMonth++;
    }

    // Maintenance
    final List<MaintenanceRecord> maintenance = MaintenanceBoxes.isInitialized
        ? MaintenanceBoxes.maintenance.values.toList()
        : const [];
    var completed = 0, followUp = 0;
    for (final rec in maintenance) {
      if (rec.completed) completed++;
      if (rec.requiresFollowUp) followUp++;
    }

    // Schedule
    final List<ScheduledTask> tasks = Hive.isBoxOpen(ScheduledTasksBox.boxName)
        ? ScheduledTasksBox.box.values.toList()
        : const [];
    var upcoming = 0, overdue = 0;
    for (final t in tasks) {
      final active = t.status == 'scheduled' || t.status == 'overdue';
      if (!active) continue;
      if (t.scheduledAt.isAfter(now)) {
        upcoming++;
      } else {
        overdue++;
      }
    }

    return _Metrics(
      totalInspections: inspections.length,
      green: green,
      amber: amber,
      red: red,
      ungraded: ungraded,
      deficiencies: deficiencies,
      loadTestsDone: loadTestsDone,
      inspectionsThisMonth: thisMonth,
      totalMaintenance: maintenance.length,
      maintenanceCompleted: completed,
      maintenanceOpen: maintenance.length - completed,
      maintenanceFollowUp: followUp,
      upcomingTasks: upcoming,
      overdueTasks: overdue,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeBreakdown extends StatelessWidget {
  const _GradeBreakdown({
    required this.green,
    required this.amber,
    required this.red,
    required this.ungraded,
    required this.theme,
  });

  final int green;
  final int amber;
  final int red;
  final int ungraded;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final total = green + amber + red + ungraded;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site grade distribution',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (total == 0)
              Text(
                'No inspections yet',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    _bar(green, total, Colors.green),
                    _bar(amber, total, Colors.orange),
                    _bar(red, total, Colors.red),
                    _bar(ungraded, total, theme.colorScheme.outlineVariant),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legend('Green', green, Colors.green),
                  _legend('Amber', amber, Colors.orange),
                  _legend('Red', red, Colors.red),
                  _legend('Ungraded', ungraded,
                      theme.colorScheme.outlineVariant),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(int value, int total, Color color) {
    if (value == 0) return const SizedBox.shrink();
    return Expanded(
      flex: value,
      child: Container(height: 14, color: color),
    );
  }

  Widget _legend(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.label,
    required this.done,
    required this.total,
    required this.theme,
  });

  final String label;
  final int done;
  final int total;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$done of $total completed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
