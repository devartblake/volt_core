import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/theme/status_colors.dart';
import '../../../domain/analytics_series.dart';
import '../../../domain/analytics_snapshot.dart';
import 'analytics_chart_card.dart';
import 'analytics_painters.dart';

String _plural(int n, String one, [String? many]) => n == 1 ? one : (many ?? '${one}s');

String _periodWords(AnalyticsPeriod p, int weeks) => switch (p) {
      AnalyticsPeriod.all => 'all time (up to $weeks weeks shown)',
      _ => 'last $weeks weeks',
    };

/// Inspections per Monday-start week.
class WeeklyInspectionsChart extends StatelessWidget {
  const WeeklyInspectionsChart({
    super.key,
    required this.inspections,
    required this.period,
    required this.now,
  });

  final List<InspectionPoint> inspections;
  final AnalyticsPeriod period;
  final DateTime now;

  /// The series this chart draws (exposed for tests).
  static List<TimeBucket> series(
    List<InspectionPoint> inspections,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final dates = [for (final i in inspections) i.date];
    return weeklyBuckets(dates, now: now, weeks: weeksFor(period, dates, now));
  }

  static String semantics(List<TimeBucket> b) {
    final peak = b.reduce((a, c) => c.count > a.count ? c : a);
    return 'Inspections per week, ${b.length} weeks: ${bucketTotal(b)} total. '
        'Peak ${peak.count} in the week of ${shortDate(peak.start)}. '
        'Latest week ${b.last.count}. Values: ${b.map((e) => e.count).join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final b = series(inspections, period, now);
    final total = bucketTotal(b);
    return AnalyticsChartCard(
      title: 'Inspections per week',
      caption: 'Weeks start on Monday, ${_periodWords(period, b.length)}.',
      total: total,
      isEmpty: total == 0,
      child: total == 0
          ? const SizedBox.shrink()
          : TimeSeriesChart(
              buckets: b,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: semantics(b),
              labelOf: (_, x) => shortDate(x.start),
              readoutOf: (x) => 'Week of ${shortDate(x.start)}: ${x.count} '
                  '${_plural(x.count, 'inspection')}',
            ),
    );
  }
}

/// Inspections per calendar month, as a line.
class MonthlyInspectionsChart extends StatelessWidget {
  const MonthlyInspectionsChart({
    super.key,
    required this.inspections,
    required this.period,
    required this.now,
  });

  final List<InspectionPoint> inspections;
  final AnalyticsPeriod period;
  final DateTime now;

  static List<TimeBucket> series(
    List<InspectionPoint> inspections,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final dates = [for (final i in inspections) i.date];
    return monthlyBuckets(dates, now: now, months: monthsFor(period, dates, now));
  }

  /// "Nov", or "Jan 27" for January and the first month shown.
  static String monthLabel(int index, TimeBucket b) => (index == 0 || b.start.month == 1)
      ? '${monthAbbr(b.start.month)} ${b.start.year % 100}'
      : monthAbbr(b.start.month);

  static String monthName(TimeBucket b) => '${monthAbbr(b.start.month)} ${b.start.year}';

  static String semantics(List<TimeBucket> b) {
    final peak = b.reduce((a, c) => c.count > a.count ? c : a);
    return 'Inspections per month, ${b.length} months: ${bucketTotal(b)} total. '
        'Busiest month ${monthName(peak)} with ${peak.count}. '
        'Latest month ${b.last.count}. Values: ${b.map((e) => e.count).join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final b = series(inspections, period, now);
    final total = bucketTotal(b);
    return AnalyticsChartCard(
      title: 'Inspections per month',
      caption: 'Last ${b.length} months by service date.',
      total: total,
      isEmpty: total == 0,
      child: total == 0
          ? const SizedBox.shrink()
          : TimeSeriesChart(
              line: true,
              buckets: b,
              color: Theme.of(context).colorScheme.tertiary,
              semanticLabel: semantics(b),
              labelOf: monthLabel,
              readoutOf: (x) => '${monthName(x)}: ${x.count} ${_plural(x.count, 'inspection')}',
            ),
    );
  }
}

/// Green / Amber / Red split as a donut; the legend rows open the list.
class GradeSplitChart extends StatelessWidget {
  const GradeSplitChart({
    super.key,
    required this.split,
    required this.period,
    this.onOpenGrade,
  });

  final GradeSplit split;
  final AnalyticsPeriod period;

  /// Called with 'green' / 'amber' / 'red'. Null disables the links.
  final void Function(String grade)? onOpenGrade;

  /// Grades of the inspections inside [period].
  static GradeSplit splitFor(
    List<InspectionPoint> inspections,
    AnalyticsPeriod period,
    DateTime now,
  ) =>
      gradeSplit([
        for (final i in period.filter(inspections, (i) => i.date, now: now)) i.grade,
      ]);

  static String semantics(GradeSplit s) =>
      'Site grades: ${s.total} inspections. ${s.green} green, ${s.amber} amber, '
      '${s.red} red, ${s.ungraded} ungraded';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String, int, Color)>[
      ('green', 'Green', split.green, theme.status.success),
      ('amber', 'Amber', split.amber, theme.status.warning),
      ('red', 'Red', split.red, theme.colorScheme.error),
      ('', 'Ungraded', split.ungraded, theme.colorScheme.outline),
    ];
    final total = split.total;
    return AnalyticsChartCard(
      title: 'Site grades',
      caption: period == AnalyticsPeriod.all
          ? 'All inspections. Tap a grade to open the list.'
          : 'Inspections in the last ${period.label}. Tap a grade to open the list.',
      total: total,
      isEmpty: total == 0,
      child: total == 0
          ? const SizedBox.shrink()
          : LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 340;
              final donut = Semantics(
                label: semantics(split),
                image: true,
                container: true,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(132),
                        painter: DonutPainter(
                          slices: [for (final r in rows) DonutSlice(r.$3.toDouble(), r.$4)],
                          trackColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$total',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in rows)
                    LegendRow(
                      color: r.$4,
                      label: r.$2,
                      count: r.$3,
                      percent: (r.$3 * 100 / total).round(),
                      onTap: (onOpenGrade != null && r.$1.isNotEmpty && r.$3 > 0)
                          ? () => onOpenGrade!(r.$1)
                          : null,
                      semanticLabel:
                          'Open ${r.$3} ${r.$2} ${_plural(r.$3, 'inspection')}',
                    ),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    donut,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: donut),
                  const SizedBox(height: AppSpacing.md),
                  legend,
                ],
              );
            }),
    );
  }
}

/// The five sites with the most red-grade inspections.
class TopRedSitesChart extends StatelessWidget {
  const TopRedSitesChart({
    super.key,
    required this.inspections,
    required this.period,
    required this.now,
  });

  final List<InspectionPoint> inspections;
  final AnalyticsPeriod period;
  final DateTime now;

  static List<LabelCount> series(
    List<InspectionPoint> inspections,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final inPeriod = period.filter(inspections, (i) => i.date, now: now);
    return topN([
      for (final i in inPeriod)
        if (i.grade.trim().toLowerCase() == 'red') i.siteCode,
    ], 5);
  }

  @override
  Widget build(BuildContext context) {
    final rows = series(inspections, period, now);
    final total = rows.fold<int>(0, (s, r) => s + r.count);
    return AnalyticsChartCard(
      title: 'Sites with most red grades',
      caption: 'Top 5 sites by red-grade inspections'
          '${period == AnalyticsPeriod.all ? '' : ', last ${period.label}'}.',
      total: total,
      isEmpty: rows.isEmpty,
      child: rows.isEmpty
          ? const SizedBox.shrink()
          : BarRows(
              rows: rows,
              colorOf: (_, __) => Theme.of(context).colorScheme.error,
              semanticLabel: 'Red-grade inspections by site, top ${rows.length}: '
                  '${rows.map((r) => '${r.label} ${r.count}').join(', ')}. $total total',
            ),
    );
  }
}
