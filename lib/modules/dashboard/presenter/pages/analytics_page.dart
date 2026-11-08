import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../inventory/infra/inventory_repository.dart';
import '../../../work_orders/presenter/work_order_providers.dart';
import '../../domain/analytics_snapshot.dart';
import '../analytics_providers.dart';
import '../dashboard_providers.dart';
import '../widgets/analytics/analytics_chart_card.dart';
import '../widgets/analytics/inspection_charts.dart';
import '../widgets/analytics/operations_charts.dart';

/// Analytics overview computed from local Hive data: inspection volume and site
/// grades, maintenance completion, and schedule health, with a graph for each.
/// Offline-friendly: it reads whatever is on device. Jobs, technician workload
/// and parts stock come from their providers and only show for roles that may
/// see them.
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(analyticsRefreshProvider.notifier).state++;
    ref.invalidate(workOrderListProvider);
    ref.invalidate(analyticsOrdersProvider);
    ref.invalidate(stockLevelsProvider);
    ref.invalidate(analyticsStockProvider);
    ref.invalidate(dashboardTechniciansProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(analyticsSnapshotProvider);
    final period = ref.watch(analyticsPeriodProvider);
    final access = ref.watch(analyticsAccessProvider);
    final now = ref.watch(analyticsClockProvider)();
    final m = AnalyticsMetrics.from(snapshot, now);

    final orders = ref.watch(analyticsOrdersProvider).value;
    final stock = ref.watch(analyticsStockProvider).value;
    final techs = access.workload ? ref.watch(dashboardTechniciansProvider).value : null;

    void openGrade(String grade) => context.push('${RoutePaths.inspections}?grade=$grade');

    return AppPage(
      title: 'Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => _refresh(ref),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AnalyticsPeriodSelector(),
            const SizedBox(height: 16),
            _SectionLabel('Inspections', theme: theme),
            _StatGrid(
              children: [
                StatCard.tile(
                  label: 'Total inspections',
                  value: '${m.totalInspections}',
                  icon: Icons.fact_check_outlined,
                  color: theme.colorScheme.primary,
                ),
                StatCard.tile(
                  label: 'With deficiencies',
                  value: '${m.deficiencies}',
                  icon: Icons.report_problem_outlined,
                  color: theme.status.warning,
                ),
                StatCard.tile(
                  label: 'Load tests done',
                  value: '${m.loadTestsDone}',
                  icon: Icons.speed_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                StatCard.tile(
                  label: 'This month',
                  value: '${m.inspectionsThisMonth}',
                  icon: Icons.calendar_today_outlined,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ChartGrid(children: [
              WeeklyInspectionsChart(
                  inspections: snapshot.inspections, period: period, now: now),
              MonthlyInspectionsChart(
                  inspections: snapshot.inspections, period: period, now: now),
              GradeSplitChart(
                split: GradeSplitChart.splitFor(snapshot.inspections, period, now),
                period: period,
                onOpenGrade: openGrade,
              ),
              TopRedSitesChart(inspections: snapshot.inspections, period: period, now: now),
            ]),
            const SizedBox(height: 24),

            _SectionLabel('Maintenance', theme: theme),
            _StatGrid(
              children: [
                StatCard.tile(
                  label: 'Total jobs',
                  value: '${m.totalMaintenance}',
                  icon: Icons.build_outlined,
                  color: theme.colorScheme.primary,
                ),
                StatCard.tile(
                  label: 'Completed',
                  value: '${m.maintenanceCompleted}',
                  icon: Icons.check_circle_outline,
                  color: theme.status.success,
                ),
                StatCard.tile(
                  label: 'Open',
                  value: '${m.maintenanceOpen}',
                  icon: Icons.pending_actions_outlined,
                  color: theme.colorScheme.secondary,
                ),
                StatCard.tile(
                  label: 'Needs follow-up',
                  value: '${m.maintenanceFollowUp}',
                  icon: Icons.flag_outlined,
                  color: theme.colorScheme.error,
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
            const SizedBox(height: 12),
            _ChartGrid(children: [
              MaintenanceChart(records: snapshot.maintenance, period: period, now: now),
            ]),
            const SizedBox(height: 24),

            _SectionLabel('Schedule', theme: theme),
            _StatGrid(
              children: [
                StatCard.tile(
                  label: 'Upcoming',
                  value: '${m.upcomingTasks}',
                  icon: Icons.event_available_outlined,
                  color: theme.colorScheme.primary,
                ),
                StatCard.tile(
                  label: 'Overdue',
                  value: '${m.overdueTasks}',
                  icon: Icons.event_busy_outlined,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            if (orders != null || techs != null || stock != null) ...[
              const SizedBox(height: 12),
              _ChartGrid(children: [
                if (orders != null) JobsChart(orders: orders, now: now),
                if (techs != null)
                  WorkloadChart(
                    tasks: snapshot.tasks,
                    names: techs.names,
                    roster: techs.roster,
                    now: now,
                  ),
                if (stock != null) InventoryChart(split: stock),
              ]),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of stat tiles. The row height follows the text size, so a
/// larger system font makes the tiles taller instead of overflowing them.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 104 * scale,
      ),
      children: children,
    );
  }
}

/// Chart cards in one column, or two from 900 dp of content width.
class _ChartGrid extends StatelessWidget {
  const _ChartGrid({required this.children});

  final List<Widget> children;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900 || children.length < 2) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              children[i],
            ],
          ],
        );
      }
      final w = (c.maxWidth - _gap) / 2;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
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
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
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
