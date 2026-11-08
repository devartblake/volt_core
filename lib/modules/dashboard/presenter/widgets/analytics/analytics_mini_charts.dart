import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/status_colors.dart';
import '../../../domain/analytics_mini_series.dart';
import '../../../domain/analytics_series.dart';
import '../../../domain/analytics_snapshot.dart';
import 'analytics_painters.dart';
import 'inspection_charts.dart';

/// Small graphs for the Analytics number cards. Drawn with [CustomPainter] (no
/// chart package), theme and status colours only, and a flat dashed track when
/// the data is all zero or the box is too small. The graph has no semantics of
/// its own: the card reads [MiniGraph.semantics] together with its number.

/// A mini graph and the sentence a screen reader gets for it.
class MiniGraph {
  const MiniGraph(this.widget, this.semantics);

  final Widget widget;
  final String semantics;
}

/// Height of every mini graph.
const double kMiniGraphHeight = 28;

String _plural(int n, String one, [String? many]) => n == 1 ? one : (many ?? '${one}s');

/// Number tile with a mini graph beside the value. Same look as
/// `StatCard.tile` (label top-left, icon top-right, value in the accent
/// colour), plus the graph; one Semantics label: "label: value. graph words".
class AnalyticsMiniTile extends StatelessWidget {
  const AnalyticsMiniTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.graph,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final MiniGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: '$label: $value. ${graph.semantics}',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              LayoutBuilder(builder: (context, c) {
                return Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth * 0.5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: graph.widget),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// A strip of bars, one per value. [highlight] is drawn in full colour, the
/// others softer; zero bars are short stubs. All zero is a dashed baseline.
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    required this.color,
    this.highlight,
    this.height = kMiniGraphHeight,
  });

  final List<int> values;
  final Color color;
  final int? highlight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: MiniBarsPainter(
          values: values,
          color: color,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
          highlight: highlight,
        ),
      ),
    );
  }
}

class MiniBarsPainter extends CustomPainter {
  MiniBarsPainter({
    required this.values,
    required this.color,
    required this.trackColor,
    this.highlight,
  });

  final List<int> values;
  final Color color;
  final Color trackColor;
  final int? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width < 6 || size.height < 6) return;
    final maxV = values.reduce(math.max);
    final base = size.height - 1;
    if (maxV <= 0) {
      final p = Paint()
        ..color = trackColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var x = 1.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, base), Offset(math.min(x + 4, size.width - 1), base), p);
      }
      return;
    }
    final slot = size.width / values.length;
    final barW = (slot * 0.68).clamp(1.0, 8.0).toDouble();
    final soft = color.withValues(alpha: 0.5);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = v <= 0 ? 2.0 : math.max(3.0, (size.height - 3) * v / maxV);
      final c = v <= 0 ? trackColor : (i == highlight || highlight == null ? color : soft);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(slot * (i + 0.5) - barW / 2, base - h, barW, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(MiniBarsPainter old) =>
      old.color != color ||
      old.trackColor != trackColor ||
      old.highlight != highlight ||
      old.values.length != values.length ||
      [for (var i = 0; i < values.length; i++) i].any((i) => old.values[i] != values[i]);
}

/// A ring with [fraction] (0..1) of the whole filled in [color]. Zero is just
/// the track.
class MiniShareRing extends StatelessWidget {
  const MiniShareRing({
    super.key,
    required this.part,
    required this.whole,
    required this.color,
    this.size = kMiniGraphHeight,
  });

  final int part;
  final int whole;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    final p = math.min(math.max(part, 0), math.max(whole, 0));
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: DonutPainter(
          slices: whole <= 0
              ? const []
              : [DonutSlice(p.toDouble(), color), DonutSlice((whole - p).toDouble(), track)],
          trackColor: track,
          strokeRatio: 0.24,
        ),
      ),
    );
  }
}

/// One rounded bar split into [segments]; empty or all zero is the track.
class MiniStack extends StatelessWidget {
  const MiniStack({super.key, required this.segments});

  final List<(int, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 10,
      child: CustomPaint(
        painter: StackedBarPainter(
          slices: [for (final s in segments) DonutSlice(s.$1.toDouble(), s.$2)],
          trackColor: theme.colorScheme.outlineVariant,
          gapColor: theme.cardTheme.color ?? theme.colorScheme.surface,
        ),
      ),
    );
  }
}

/// Builds the graph for each Analytics number card from plain values.
class AnalyticsMinis {
  const AnalyticsMinis._();

  static String _latestWord(AnalyticsPeriod p, int n) =>
      p == AnalyticsPeriod.all ? 'up to $n weeks' : 'last $n weeks';

  /// Total inspections: weekly counts, newest week highlighted. Follows the
  /// period selector.
  static MiniGraph totalInspections(
    ThemeData theme,
    List<InspectionPoint> inspections,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final b = WeeklyInspectionsChart.series(inspections, period, now);
    final v = [for (final e in b) e.count];
    final total = bucketTotal(b);
    return MiniGraph(
      MiniBars(values: v, color: theme.colorScheme.primary, highlight: v.length - 1),
      total == 0
          ? 'Per week, ${_latestWord(period, b.length)}: no inspections'
          : 'Per week, ${_latestWord(period, b.length)}: $total '
              '${_plural(total, 'inspection')}, this week ${v.last}',
    );
  }

  /// With deficiencies: share of all inspections.
  static MiniGraph deficiencies(ThemeData theme, AnalyticsMetrics m) => MiniGraph(
        MiniShareRing(
            part: m.deficiencies, whole: m.totalInspections, color: theme.status.warning),
        '${m.deficiencies} of ${m.totalInspections} inspections '
        '(${percentOf(m.deficiencies, m.totalInspections)}%) have deficiencies',
      );

  /// Load tests done: share of all inspections.
  static MiniGraph loadTests(ThemeData theme, AnalyticsMetrics m) => MiniGraph(
        MiniShareRing(
            part: m.loadTestsDone, whole: m.totalInspections, color: theme.colorScheme.tertiary),
        '${m.loadTestsDone} of ${m.totalInspections} inspections '
        '(${percentOf(m.loadTestsDone, m.totalInspections)}%) had a load test',
      );

  /// This month: inspections created per day, today highlighted.
  static MiniGraph thisMonth(
    ThemeData theme,
    List<InspectionPoint> inspections,
    DateTime now,
  ) {
    final v = inspectionsCreatedThisMonth(inspections, now);
    final total = v.fold<int>(0, (s, e) => s + e);
    return MiniGraph(
      MiniBars(values: v, color: theme.colorScheme.secondary, highlight: now.day - 1),
      total == 0
          ? 'By day, ${monthAbbr(now.month)}: no inspections yet'
          : 'By day, ${monthAbbr(now.month)} (${v.length} days): $total '
              '${_plural(total, 'inspection')}, today ${v[now.day - 1]}',
    );
  }

  /// Total jobs: maintenance records per month. Follows the period selector.
  static MiniGraph totalMaintenance(
    ThemeData theme,
    List<MaintenancePoint> records,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final dates = [for (final r in records) r.date];
    final b = monthlyBuckets(dates, now: now, months: monthsFor(period, dates, now));
    final v = [for (final e in b) e.count];
    final total = bucketTotal(b);
    return MiniGraph(
      MiniBars(values: v, color: theme.colorScheme.primary, highlight: v.length - 1),
      total == 0
          ? 'Per month, ${b.length} months: no jobs'
          : 'Per month, ${b.length} months: $total ${_plural(total, 'job')}, '
              'this month ${v.last}',
    );
  }

  static MiniGraph maintenanceShare(
    String what,
    int part,
    int whole,
    Color color,
  ) =>
      MiniGraph(
        MiniShareRing(part: part, whole: whole, color: color),
        '$part of $whole jobs (${percentOf(part, whole)}%) $what',
      );

  /// Completed per month for the progress card. Follows the period selector.
  static MiniGraph completedPerMonthStrip(
    ThemeData theme,
    List<MaintenancePoint> records,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    final dates = [for (final r in records) r.date];
    final b = completedPerMonth(records, now: now, months: monthsFor(period, dates, now));
    final v = [for (final e in b) e.count];
    final total = bucketTotal(b);
    return MiniGraph(
      MiniBars(values: v, color: theme.status.success, highlight: v.length - 1),
      total == 0
          ? 'Completed per month, ${b.length} months: none'
          : 'Completed per month, ${b.length} months: $total, this month ${v.last}',
    );
  }

  /// Upcoming: tasks per day for the next 7 days, today first.
  static MiniGraph upcoming(ThemeData theme, List<TaskPoint> tasks, DateTime now) {
    final v = nextDaysCounts(tasks, now);
    final total = v.fold<int>(0, (s, e) => s + e);
    return MiniGraph(
      MiniBars(values: v, color: theme.colorScheme.primary, highlight: 0),
      total == 0
          ? 'Next 7 days: nothing scheduled'
          : 'Next 7 days: $total ${_plural(total, 'task')}, today ${v.first}',
    );
  }

  /// Overdue: how late, as one stacked bar.
  static MiniGraph overdue(ThemeData theme, List<TaskPoint> tasks, DateTime now) {
    final a = overdueAges(overdueTaskDates(tasks, now), now);
    return MiniGraph(
      MiniStack(segments: [
        (a.week, theme.status.warning),
        (a.month, theme.colorScheme.error.withValues(alpha: 0.65)),
        (a.older, theme.colorScheme.error),
      ]),
      a.total == 0
          ? 'None overdue'
          : 'Overdue by age: ${a.week} up to 7 days, ${a.month} 8 to 30 days, '
              '${a.older} 31 days or more',
    );
  }
}
