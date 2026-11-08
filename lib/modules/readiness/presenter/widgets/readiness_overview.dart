import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_summary.dart';
import '../../domain/readiness_view.dart';
import 'readiness_charts.dart';
import 'readiness_visuals.dart';

/// The top of the dashboard: as-of line, hero number, donut, the four status
/// tiles (tap to filter), the due-by-week chart, the grade split and the five
/// worst units.
class ReadinessOverview extends StatelessWidget {
  const ReadinessOverview({
    super.key,
    required this.summary,
    required this.now,
    required this.filter,
    required this.onToggleStatus,
    required this.onSelectWeek,
    required this.onOpenUnit,
    required this.onRefresh,
    this.refreshing = false,
  });

  final ReadinessSummary summary;
  final DateTime now;
  final ReadinessFilter filter;
  final ValueChanged<ReadinessStatus> onToggleStatus;
  final void Function(DateTime? weekStart) onSelectWeek;
  final ValueChanged<ReadinessUnit> onOpenUnit;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 640;
      final hero = _Hero(summary: summary, now: now);
      final tiles = _StatTiles(
        summary: summary,
        selected: filter.statuses,
        onToggle: onToggleStatus,
        columns: wide ? 4 : 2,
      );
      final charts = _Card(
        title: 'Due by week',
        subtitle: 'Next inspection due. Tap a bar to filter the list.',
        child: DueByWeekChart(
          summary: summary,
          now: now,
          onSelect: onSelectWeek,
          selectedWeek: filter.dueWeekStart,
          overdueSelected: filter.dueWindow == ReadinessDueWindow.overdue,
        ),
      );
      final grades = _Card(
        title: 'Last inspection grade',
        child: GradeBar(counts: summary.gradeCounts),
      );
      final worst = _Worst(units: summary.worstUnits, onOpen: onOpenUnit);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'As of ${readinessClock(now)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          hero,
          const SizedBox(height: AppSpacing.md),
          tiles,
          const SizedBox(height: AppSpacing.md),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: charts),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: Column(children: [grades, worst])),
              ],
            )
          else ...[
            charts,
            grades,
            worst,
          ],
        ],
      );
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.now});

  final ReadinessSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = summary;
    final size = MediaQuery.sizeOf(context).width < 400 ? 112.0 : 148.0;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            ReadinessDonut(summary: s, size: size),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      s.total == 0 ? 'No generators yet' : '${s.percentReady.round()}% ready',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    s.total == 1 ? '1 generator' : '${s.total} generators',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    s.overdueCount == 0
                        ? 'Nothing overdue'
                        : '${s.overdueCount} overdue',
                    key: const Key('overdue-count'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: s.overdueCount == 0
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (s.followUpCount > 0)
                    Text(
                      s.followUpCount == 1
                          ? '1 open follow-up'
                          : '${s.followUpCount} open follow-ups',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({
    required this.summary,
    required this.selected,
    required this.onToggle,
    required this.columns,
  });

  final ReadinessSummary summary;
  final Set<ReadinessStatus> selected;
  final ValueChanged<ReadinessStatus> onToggle;
  final int columns;

  static const _order = [
    ReadinessStatus.ready,
    ReadinessStatus.dueSoon,
    ReadinessStatus.attention,
    ReadinessStatus.notReady,
  ];

  static const _labels = {
    ReadinessStatus.ready: 'Ready',
    ReadinessStatus.dueSoon: 'Due soon',
    ReadinessStatus.attention: 'Attention',
    ReadinessStatus.notReady: 'Not ready',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1,
      // Fixed height rows: a tile is a label, an icon and one big number.
      mainAxisExtent: 92.0 * scale,
      children: [
        for (final st in _order)
          Container(
            key: Key('stat-${st.name}'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: selected.contains(st)
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            child: StatCard.tile(
              icon: ReadinessVisuals.statusIcon(st),
              label: _labels[st]!,
              value: '${summary.count(st)}',
              color: ReadinessVisuals.statusColor(theme, st),
              onTap: () => onToggle(st),
            ),
          ),
      ],
    );
  }
}

class _Worst extends StatelessWidget {
  const _Worst({required this.units, required this.onOpen});

  final List<ReadinessUnit> units;
  final ValueChanged<ReadinessUnit> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (units.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'Needs attention first',
      child: Column(
        children: [
          for (final u in units)
            InkWell(
              key: Key('worst-${u.key}'),
              onTap: () => onOpen(u),
              borderRadius: AppRadius.chipAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(ReadinessVisuals.statusIcon(u.status),
                          size: 20,
                          color: ReadinessVisuals.statusColor(theme, u.status)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (u.reasons.isNotEmpty)
                              Text(u.reasons.first.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
