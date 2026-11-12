import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_mini_series.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_summary.dart';
import '../../domain/readiness_view.dart';
import 'readiness_attention_row.dart';
import 'readiness_charts.dart';
import 'readiness_mini_charts.dart';
import 'readiness_stat_tile.dart';
import 'readiness_visuals.dart';

/// The top of the dashboard: as-of line, hero number with its donut, the four
/// status tiles (tap to filter, each with a small graph), the due-by-week chart
/// beside the grade split, and the five worst units as a row of cards.
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
    this.units = const [],
    this.dueSoonDays = 30,
    this.onSeeAllNotReady,
    this.refreshing = false,
  });

  final ReadinessSummary summary;
  final DateTime now;
  final ReadinessFilter filter;
  final ValueChanged<ReadinessStatus> onToggleStatus;
  final void Function(DateTime? weekStart) onSelectWeek;
  final ValueChanged<ReadinessUnit> onOpenUnit;
  final VoidCallback onRefresh;

  /// Every unit, for the reason breakdowns on the tiles.
  final List<ReadinessUnit> units;

  /// The configured due-soon window, to highlight weeks on the Due soon tile.
  final int dueSoonDays;

  /// "See all" on Needs attention first: applies the Not ready filter.
  final VoidCallback? onSeeAllNotReady;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 640;
      final twoUp = c.maxWidth >= 600;
      final hero = _Hero(summary: summary, now: now);
      final tiles = _StatTiles(
        summary: summary,
        units: units,
        now: now,
        dueSoonDays: dueSoonDays,
        selected: filter.statuses,
        onToggle: onToggleStatus,
        columns: wide ? 4 : 2,
      );
      final minH = twoUp ? 232.0 * _textScale(context) : null;
      final due = _Card(
        title: 'Due by week',
        subtitle: 'Next inspection due. Tap a bar to filter the list.',
        minHeight: minH,
        child: dueChartIsEmpty(summary)
            ? _NoDueDates(
                estimated: estimatedDueCount(units),
                dueLater: summary.dueLater,
              )
            : DueByWeekChart(
                summary: summary,
                now: now,
                onSelect: onSelectWeek,
                selectedWeek: filter.dueWeekStart,
                overdueSelected: filter.dueWindow == ReadinessDueWindow.overdue,
              ),
      );
      final grades = _Card(
        title: 'Last inspection grade',
        subtitle: 'Latest graded inspection of each generator.',
        minHeight: minH,
        child: GradeBreakdown(counts: summary.gradeCounts),
      );
      final attention = ReadinessAttentionRow(
        units: summary.worstUnits,
        onOpen: onOpenUnit,
        onSeeAll: onSeeAllNotReady ?? () => onToggleStatus(ReadinessStatus.notReady),
      );

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
          if (twoUp)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: due),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: grades),
              ],
            )
          else ...[
            due,
            grades,
          ],
          attention,
        ],
      );
    });
  }
}

double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.minHeight,
  });

  final String title;
  final String? subtitle;
  final double? minHeight;
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
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight ?? 0),
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
      ),
    );
  }
}

/// Shown instead of a flat chart when nothing has a due date in range.
class _NoDueDates extends StatelessWidget {
  const _NoDueDates({required this.estimated, required this.dueLater});

  final int estimated;
  final int dueLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headline = dueLater > 0
        ? 'Nothing is due in the next 12 weeks.'
        : 'No next-inspection dates set yet. Due dates shown are estimates.';
    final estimate = estimated == 0
        ? null
        : estimated == 1
            ? '1 generator has an estimated due date'
            : '$estimated generators have an estimated due date';
    return Semantics(
      container: true,
      label: [
        headline,
        if (estimate != null) estimate,
        if (dueLater > 0) '$dueLater due later',
      ].join('. '),
      excludeSemantics: true,
      child: Row(
        key: const Key('due-empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_note_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: theme.textTheme.bodyMedium),
                if (estimate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(estimate,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                if (dueLater > 0)
                  Text('$dueLater due later',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Green / Amber / Red / Ungraded split: a stacked bar, then a row per
/// grade with its count and share.
class GradeBreakdown extends StatelessWidget {
  const GradeBreakdown({super.key, required this.counts});

  final Map<ReadinessGrade, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Semantics(
      container: true,
      label: GradeBar.semanticLabel(counts),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniStackBar(
            height: 12,
            semanticLabel: GradeBar.semanticLabel(counts),
            segments: [
              for (final g in ReadinessGrade.values)
                MiniSegment(counts[g] ?? 0, ReadinessVisuals.gradeColor(theme, g)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final g in ReadinessGrade.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: ReadinessVisuals.gradeColor(theme, g),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(g.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    total == 0
                        ? '${counts[g] ?? 0}'
                        : '${counts[g] ?? 0}  (${((counts[g] ?? 0) * 100 / total).round()}%)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
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
    final notOverdue = (s.total - s.overdueCount).clamp(0, s.total);
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
                  const SizedBox(height: AppSpacing.xs),
                  // Overdue against the rest of the fleet.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: MiniStackBar(
                      key: const Key('overdue-bar'),
                      height: 8,
                      semanticLabel: s.total == 0
                          ? 'No generators'
                          : '${s.overdueCount} of ${s.total} generators overdue',
                      segments: [
                        MiniSegment(s.overdueCount, scheme.error),
                        MiniSegment(notOverdue, scheme.outlineVariant),
                      ],
                    ),
                  ),
                  if (s.followUpCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        s.followUpCount == 1
                            ? '1 open follow-up'
                            : '${s.followUpCount} open follow-ups',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
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
    required this.units,
    required this.now,
    required this.dueSoonDays,
    required this.selected,
    required this.onToggle,
    required this.columns,
  });

  final ReadinessSummary summary;
  final List<ReadinessUnit> units;
  final DateTime now;
  final int dueSoonDays;
  final Set<ReadinessStatus> selected;
  final ValueChanged<ReadinessStatus> onToggle;
  final int columns;

  static const _order = [
    ReadinessStatus.ready,
    ReadinessStatus.dueSoon,
    ReadinessStatus.attention,
    ReadinessStatus.notReady,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1,
      // Fixed height rows: a label and icon, then the count beside its graph.
      mainAxisExtent: 96.0 * _textScale(context),
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
            child: ReadinessStatTile(
              status: st,
              summary: summary,
              units: units,
              now: now,
              dueSoonDays: dueSoonDays,
              onTap: () => onToggle(st),
            ),
          ),
      ],
    );
  }
}
