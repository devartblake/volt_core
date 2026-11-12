import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/theme/status_colors.dart';
import '../../../../work_orders/domain/entities/work_order_entity.dart';
import '../../../domain/analytics_series.dart';
import 'analytics_chart_card.dart';
import 'inspection_charts.dart';

/// Work orders by status, plus how many open ones are overdue.
class JobsChart extends StatelessWidget {
  const JobsChart({super.key, required this.orders, required this.now});

  final List<OrderPoint> orders;
  final DateTime now;

  static String statusSemantics(List<LabelCount> rows) =>
      'Jobs by status: ${rows.fold<int>(0, (s, r) => s + r.count)} total. '
      '${rows.map((r) => '${r.label} ${r.count}').join(', ')}';

  static String overdueSemantics(int onTime, int overdue) =>
      'Open jobs: ${onTime + overdue}. $onTime on time, $overdue overdue';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = ordersByStatus(orders);
    final split = overdueSplit(orders, now);
    Color colorOf(int i, LabelCount r) => switch (WorkOrderStatus.values[i]) {
          WorkOrderStatus.draft => theme.colorScheme.outline,
          WorkOrderStatus.scheduled => theme.status.info,
          WorkOrderStatus.inProgress => theme.colorScheme.primary,
          WorkOrderStatus.completed => theme.status.success,
          WorkOrderStatus.cancelled => theme.colorScheme.outline,
        };
    return AnalyticsChartCard(
      title: 'Jobs by status',
      caption: 'Every job in the queue, and open jobs dated before today.',
      total: orders.length,
      isEmpty: orders.isEmpty,
      child: orders.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarRows(rows: rows, colorOf: colorOf, semanticLabel: statusSemantics(rows)),
                const SizedBox(height: AppSpacing.xs),
                Text('Open jobs', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                if (split.onTime + split.overdue == 0)
                  Text('No open jobs.', style: theme.textTheme.bodySmall)
                else
                  SplitBar(
                    semanticLabel: overdueSemantics(split.onTime, split.overdue),
                    segments: [
                      ('On time', split.onTime, theme.status.success),
                      ('Overdue', split.overdue, theme.colorScheme.error),
                    ],
                  ),
              ],
            ),
    );
  }
}

/// Maintenance records completed per month, and in progress vs completed.
class MaintenanceChart extends StatelessWidget {
  const MaintenanceChart({
    super.key,
    required this.records,
    required this.period,
    required this.now,
  });

  final List<MaintenancePoint> records;
  final AnalyticsPeriod period;
  final DateTime now;

  static List<MaintenancePoint> inPeriod(
    List<MaintenancePoint> records,
    AnalyticsPeriod period,
    DateTime now,
  ) =>
      period.filter(records, (r) => r.date, now: now);

  static List<TimeBucket> series(
    List<MaintenancePoint> records,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final dates = [for (final r in records) r.date];
    return completedPerMonth(records, now: now, months: monthsFor(period, dates, now));
  }

  static String monthlySemantics(List<TimeBucket> b) =>
      'Maintenance records completed per month, ${b.length} months: '
      '${bucketTotal(b)} total. Latest month ${b.last.count}. '
      'Values: ${b.map((e) => e.count).join(', ')}';

  static String splitSemantics(int inProgress, int completed) =>
      'Maintenance records: ${inProgress + completed}. '
      '$completed completed, $inProgress in progress';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoped = inPeriod(records, period, now);
    final b = series(records, period, now);
    final split = maintenanceSplit(scoped);
    final total = scoped.length;
    final completedTotal = bucketTotal(b);
    return AnalyticsChartCard(
      title: 'Maintenance records',
      caption: 'Completed per month, and how many are still in progress'
          '${period == AnalyticsPeriod.all ? '' : ' (last ${period.label})'}.',
      total: total,
      isEmpty: total == 0,
      child: total == 0
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (completedTotal == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('None completed in these months yet.',
                        style: theme.textTheme.bodySmall),
                  )
                else ...[
                  TimeSeriesChart(
                    buckets: b,
                    color: theme.status.success,
                    semanticLabel: monthlySemantics(b),
                    labelOf: MonthlyInspectionsChart.monthLabel,
                    readoutOf: (x) => '${MonthlyInspectionsChart.monthName(x)}: '
                        '${x.count} completed',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                SplitBar(
                  semanticLabel: splitSemantics(split.inProgress, split.completed),
                  segments: [
                    ('Completed', split.completed, theme.status.success),
                    ('In progress', split.inProgress, theme.status.info),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Tasks per technician this week (dispatcher and admin).
class WorkloadChart extends StatelessWidget {
  const WorkloadChart({
    super.key,
    required this.tasks,
    required this.names,
    required this.roster,
    required this.now,
  });

  final List<TaskPoint> tasks;
  final Map<String, String> names;
  final List<String> roster;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rows = tasksPerTechnician(tasks, now: now, names: names, roster: roster);
    final total = rows.fold<int>(0, (s, r) => s + r.count);
    return AnalyticsChartCard(
      title: 'Technician workload',
      caption: 'Tasks per technician this week, Monday to Sunday.',
      total: total,
      isEmpty: total == 0,
      child: total == 0
          ? const SizedBox.shrink()
          : BarRows(
              rows: rows,
              colorOf: (_, r) => r.label == 'Unassigned'
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
              semanticLabel: 'Tasks per technician this week: $total total. '
                  '${rows.map((r) => '${r.label} ${r.count}').join(', ')}',
            ),
    );
  }
}

/// Parts in stock, low and out (admin, supervisor, dispatcher).
class InventoryChart extends StatelessWidget {
  const InventoryChart({super.key, required this.split});

  final StockSplit split;

  static String semantics(StockSplit s) =>
      'Parts: ${s.total}. ${s.ok} in stock, ${s.low} low, ${s.out} out of stock';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnalyticsChartCard(
      title: 'Parts stock',
      caption: 'Parts in stock, at or below their minimum, and out.',
      total: split.total,
      isEmpty: split.total == 0,
      child: split.total == 0
          ? const SizedBox.shrink()
          : SplitBar(
              semanticLabel: semantics(split),
              segments: [
                ('In stock', split.ok, theme.status.success),
                ('Low', split.low, theme.status.warning),
                ('Out of stock', split.out, theme.colorScheme.error),
              ],
            ),
    );
  }
}
