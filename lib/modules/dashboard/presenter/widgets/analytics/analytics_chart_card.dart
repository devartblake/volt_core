import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../domain/analytics_series.dart';
import '../../analytics_providers.dart';
import 'analytics_painters.dart';

/// Text shown by every chart that has nothing to draw.
const String kNotEnoughData = 'Not enough data yet';

/// Frame for one graph: title, "N total", a one-line caption, then the chart
/// (or the empty state).
class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.caption,
    required this.total,
    required this.isEmpty,
    required this.child,
  });

  final String title;
  final String caption;

  /// Shown top right as "N total"; pass the number only.
  final int total;
  final bool isEmpty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$total total',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isEmpty)
              Semantics(
                container: true,
                label: '$title: $kNotEnoughData',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_outlined,
                            size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            kNotEnoughData,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              child,
          ],
        ),
      ),
    );
  }
}

/// Colour swatch + label + count (+ optional share), optionally tappable.
class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.count,
    this.percent,
    this.onTap,
    this.semanticLabel,
  });

  final Color color;
  final String label;
  final int count;
  final int? percent;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: onTap == null ? 28 : 48),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            percent == null ? '$count' : '$count  ($percent%)',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: semanticLabel ?? '$label, $count',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// A row of "label  count" with a bar under it. Stacked rather than side by
/// side, so long names and large text sizes wrap instead of overflowing.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int count;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 10,
            width: double.infinity,
            child: CustomPaint(
              painter: HorizontalBarsPainter(
                fraction: fraction,
                color: color,
                trackColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bars for [rows], scaled to the largest. [colorOf] picks a colour
/// per row (defaults to the primary colour). Wrapped as one Semantics sentence.
class BarRows extends StatelessWidget {
  const BarRows({
    super.key,
    required this.rows,
    required this.semanticLabel,
    this.colorOf,
  });

  final List<LabelCount> rows;
  final String semanticLabel;
  final Color Function(int index, LabelCount row)? colorOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = rows.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return Semantics(
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            BarRow(
              label: rows[i].label,
              count: rows[i].count,
              fraction: rows[i].count / maxV,
              color: colorOf?.call(i, rows[i]) ?? scheme.primary,
            ),
        ],
      ),
    );
  }
}

/// A 100% bar with a legend underneath (counts in text, not just colour).
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.segments,
    required this.semanticLabel,
  });

  /// Label, count, colour.
  final List<(String, int, Color)> segments;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<int>(0, (s, e) => s + e.$2);
    return Semantics(
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 14,
            child: CustomPaint(
              painter: StackedBarPainter(
                slices: [for (final s in segments) DonutSlice(s.$2.toDouble(), s.$3)],
                trackColor: theme.colorScheme.surfaceContainerHighest,
                gapColor: theme.colorScheme.surface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final s in segments)
            LegendRow(
              color: s.$3,
              label: s.$1,
              count: s.$2,
              percent: total == 0 ? null : (s.$2 * 100 / total).round(),
            ),
        ],
      ),
    );
  }
}

/// Bar or line chart over time buckets with a value readout above it.
///
/// Tap, drag or hover to pick a bucket; the readout line (real text) shows its
/// value, and defaults to the latest bucket.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.buckets,
    required this.labelOf,
    required this.readoutOf,
    required this.semanticLabel,
    required this.color,
    this.line = false,
    this.plotHeight = 120,
  });

  final List<TimeBucket> buckets;
  final String Function(int index, TimeBucket b) labelOf;
  final String Function(TimeBucket b) readoutOf;
  final String semanticLabel;
  final Color color;
  final bool line;
  final double plotHeight;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  int? _selected;

  void _pick(Offset local, double width) {
    final i = BarChartPainter.indexAt(local.dx, width, widget.buckets.length);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  void didUpdateWidget(TimeSeriesChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.buckets.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(color: scheme.onSurfaceVariant);
    final axisH = AxisLabels.heightFor(labelStyle, scaler);
    final values = [for (final b in widget.buckets) b.count];
    final shown = _selected ?? widget.buckets.length - 1;
    final axis = AxisLabels(
      labels: [for (var i = 0; i < widget.buckets.length; i++) widget.labelOf(i, widget.buckets[i])],
      style: labelStyle,
      scaler: scaler,
      direction: Directionality.of(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.readoutOf(widget.buckets[shown]),
          key: const Key('chart-readout'),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: widget.semanticLabel,
          image: true,
          container: true,
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return MouseRegion(
                onHover: (e) => _pick(e.localPosition, w),
                onExit: (_) => setState(() => _selected = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(d.localPosition, w),
                  onHorizontalDragUpdate: (d) => _pick(d.localPosition, w),
                  child: SizedBox(
                    height: widget.plotHeight + axisH,
                    width: w,
                    child: CustomPaint(
                      painter: widget.line
                          ? LinePainter(
                              values: values,
                              lineColor: widget.color,
                              gridColor: scheme.outlineVariant,
                              surfaceColor: scheme.surface,
                              axis: axis,
                              axisHeight: axisH,
                              selected: _selected,
                            )
                          : BarChartPainter(
                              values: values,
                              barColor: widget.color,
                              selectedColor: widget.color,
                              gridColor: scheme.outlineVariant,
                              highlightColor: scheme.surfaceContainerHighest,
                              axis: axis,
                              axisHeight: axisH,
                              selected: _selected,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The period selector shown at the top of Analytics. Labels shorten on
/// narrow screens and the row scrolls rather than overflows.
class AnalyticsPeriodSelector extends ConsumerWidget {
  const AnalyticsPeriodSelector({super.key});

  static String _short(AnalyticsPeriod p) => switch (p) {
        AnalyticsPeriod.weeks4 => '4 wk',
        AnalyticsPeriod.weeks12 => '12 wk',
        AnalyticsPeriod.months6 => '6 mo',
        AnalyticsPeriod.all => 'All',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    return Semantics(
      container: true,
      label: 'Period for the time charts',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AnalyticsPeriod>(
          showSelectedIcon: false,
          segments: [
            for (final p in AnalyticsPeriod.values)
              ButtonSegment(
                value: p,
                label: Text(compact ? _short(p) : p.label, key: Key('period-${p.name}')),
                tooltip: p.label,
              ),
          ],
          selected: {period},
          onSelectionChanged: (s) => ref.read(analyticsPeriodProvider.notifier).state = s.first,
        ),
      ),
    );
  }
}
