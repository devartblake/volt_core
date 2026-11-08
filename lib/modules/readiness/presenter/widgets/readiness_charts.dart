import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_summary.dart';
import '../../domain/readiness_view.dart';
import 'readiness_visuals.dart';

/// Donut of the status split. Drawn with a [CustomPainter]; the centre shows the
/// percent ready and the whole chart reads out as one sentence.
class ReadinessDonut extends StatelessWidget {
  const ReadinessDonut({
    super.key,
    required this.summary,
    this.size = 148,
  });

  final ReadinessSummary summary;
  final double size;

  static String semanticLabel(ReadinessSummary s) {
    if (s.total == 0) return 'Generator fleet readiness: no generators';
    return 'Generator fleet readiness: ${s.percentReady.round()}% ready. '
        '${s.count(ReadinessStatus.ready)} ready, '
        '${s.count(ReadinessStatus.dueSoon)} due soon, '
        '${s.count(ReadinessStatus.attention)} needs attention, '
        '${s.count(ReadinessStatus.notReady)} not ready, '
        'out of ${s.total} generators';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Worst first around the ring, so the red is the first thing on the right.
    final slices = [
      for (final st in ReadinessStatus.values)
        DonutSlice(s: summary.count(st).toDouble(), color: ReadinessVisuals.statusColor(theme, st)),
    ];
    return Semantics(
      label: semanticLabel(summary),
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: DonutPainter(
                slices: slices,
                trackColor: scheme.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.total == 0 ? '-' : '${summary.percentReady.round()}%',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('ready',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice({required this.s, required this.color});
  final double s;
  final Color color;
}

class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.slices,
    required this.trackColor,
  });

  final List<DonutSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.17;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    final total = slices.fold<double>(0, (a, b) => a + b.s);
    if (total <= 0) {
      canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = trackColor);
      return;
    }
    var start = -math.pi / 2;
    final shown = slices.where((s) => s.s > 0).length;
    // A hairline gap between slices; none when there is a single slice.
    final gap = shown > 1 ? 0.035 : 0.0;
    for (final s in slices) {
      if (s.s <= 0) continue;
      final sweep = s.s / total * math.pi * 2;
      canvas.drawArc(arc, start + gap / 2, math.max(0.001, sweep - gap), false,
          paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.trackColor != trackColor ||
      old.slices.length != slices.length ||
      [for (var i = 0; i < slices.length; i++) i].any(
          (i) => old.slices[i].s != slices[i].s || old.slices[i].color != slices[i].color);
}

/// 12-week "Due by week" histogram with an Overdue bar first. Each bar is a tap
/// target (to filter the list to that week) laid over one painted chart.
class DueByWeekChart extends StatelessWidget {
  const DueByWeekChart({
    super.key,
    required this.summary,
    required this.now,
    required this.onSelect,
    this.selectedWeek,
    this.overdueSelected = false,
  });

  final ReadinessSummary summary;
  final DateTime now;

  /// Called with the week's Monday, or null for the Overdue bar.
  final void Function(DateTime? weekStart) onSelect;
  final DateTime? selectedWeek;
  final bool overdueSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weeks = summary.dueByWeek;
    final counts = [for (final b in weeks) b.count];
    final maxCount = math.max(1, math.max(summary.overdueCount, counts.fold(0, math.max)));
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      container: true,
      label: 'Inspections due by week. '
          '${dueChartSummary(summary.overdueCount, counts, mondayOf(now))}',
      child: LayoutBuilder(builder: (context, c) {
        // Degrade on narrow widths: keep the bars, drop the value labels.
        final narrow = c.maxWidth < 420 || scale > 1.5;
        final labelH = narrow ? 0.0 : 18.0;
        const barsH = 110.0;
        final selectedIndex = overdueSelected
            ? 0
            : selectedWeek == null
                ? -1
                : weeks.indexWhere((b) => b.weekStart == selectedWeek) + 1;
        final bars = <_Bar>[
          _Bar('Overdue', summary.overdueCount, theme.colorScheme.error),
          for (final b in weeks)
            _Bar(readinessWeekLabel(b.weekStart), b.count, scheme.primary),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: barsH + labelH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: BarsPainter(
                          values: [for (final b in bars) b.value],
                          colors: [for (final b in bars) b.color],
                          maxValue: maxCount,
                          selected: selectedIndex,
                          trackColor: scheme.outlineVariant,
                          labelColor: scheme.onSurfaceVariant,
                          selectedColor: scheme.onSurface,
                          showValues: !narrow,
                          labelStyle: theme.textTheme.labelSmall ?? const TextStyle(),
                          reserveTop: labelH,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < bars.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == selectedIndex,
                            label: i == 0
                                ? '${bars[i].value} overdue. Show overdue units'
                                : '${bars[i].value} due week of ${bars[i].label}. '
                                    'Show that week',
                            excludeSemantics: true,
                            child: InkWell(
                              key: Key('due-bar-$i'),
                              onTap: () => onSelect(i == 0 ? null : weeks[i - 1].weekStart),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('Overdue', maxLines: 1, overflow: TextOverflow.ellipsis, style: _axis(theme))),
                if (!narrow)
                  Text('Weeks from ${readinessWeekLabel(weeks.first.weekStart)}',
                      maxLines: 1, style: _axis(theme)),
                Flexible(child: Text('+12 weeks', maxLines: 1, overflow: TextOverflow.ellipsis, style: _axis(theme))),
              ],
            ),
          ],
        );
      }),
    );
  }

  TextStyle? _axis(ThemeData t) => t.textTheme.labelSmall
      ?.copyWith(color: t.colorScheme.onSurfaceVariant);
}

/// "9 Nov".
String readinessWeekLabel(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

class _Bar {
  const _Bar(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class BarsPainter extends CustomPainter {
  BarsPainter({
    required this.values,
    required this.colors,
    required this.maxValue,
    required this.selected,
    required this.trackColor,
    required this.labelColor,
    required this.selectedColor,
    required this.showValues,
    required this.labelStyle,
    required this.reserveTop,
  });

  final List<int> values;
  final List<Color> colors;
  final int maxValue;
  final int selected;
  final Color trackColor;
  final Color labelColor;
  final Color selectedColor;
  final bool showValues;
  final TextStyle labelStyle;
  final double reserveTop;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final slot = size.width / n;
    final barW = math.min(slot * 0.62, 22.0);
    final baseY = size.height;
    final usable = size.height - reserveTop - 2;

    canvas.drawLine(Offset(0, baseY - 0.5), Offset(size.width, baseY - 0.5),
        Paint()..color = trackColor..strokeWidth = 1);

    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final h = values[i] == 0 ? 2.0 : math.max(4.0, usable * values[i] / maxValue);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, baseY - h, barW, h),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      final p = Paint()
        ..color = values[i] == 0 ? trackColor : colors[i].withValues(alpha: i == selected || selected < 0 ? 1 : 0.45);
      canvas.drawRRect(rect, p);
      if (i == selected) {
        canvas.drawRRect(
            rect.inflate(1.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = selectedColor);
      }
      if (showValues && values[i] > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${values[i]}', style: labelStyle.copyWith(color: labelColor)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: slot);
        tp.paint(canvas, Offset(cx - tp.width / 2, baseY - h - tp.height - 1));
      }
    }
  }

  @override
  bool shouldRepaint(BarsPainter old) =>
      old.values.toString() != values.toString() ||
      old.selected != selected ||
      old.maxValue != maxValue ||
      old.trackColor != trackColor ||
      old.showValues != showValues ||
      old.colors.toString() != colors.toString();
}

/// One stacked bar with the Green / Amber / Red / Ungraded split.
class GradeBar extends StatelessWidget {
  const GradeBar({super.key, required this.counts});

  final Map<ReadinessGrade, int> counts;

  static String semanticLabel(Map<ReadinessGrade, int> c) =>
      'Last inspection grades: ${c[ReadinessGrade.green] ?? 0} Green, '
      '${c[ReadinessGrade.amber] ?? 0} Amber, ${c[ReadinessGrade.red] ?? 0} Red, '
      '${c[ReadinessGrade.none] ?? 0} ungraded';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Semantics(
      label: semanticLabel(counts),
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const SizedBox.expand())
                  : Row(
                      children: [
                        for (final g in ReadinessGrade.values)
                          if ((counts[g] ?? 0) > 0)
                            Expanded(
                              flex: counts[g]!,
                              child: ColoredBox(
                                  color: ReadinessVisuals.gradeColor(theme, g),
                                  child: const SizedBox.expand()),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (final g in ReadinessGrade.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: ReadinessVisuals.gradeColor(theme, g),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${g.label} ${counts[g] ?? 0}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

/// A strip of one dot per inspection (oldest left), coloured by grade.
class GradeTrendStrip extends StatelessWidget {
  const GradeTrendStrip({super.key, required this.grades});

  final List<ReadinessGrade> grades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = grades.isEmpty
        ? 'No graded inspections'
        : 'Grade trend, oldest to newest: ${grades.map((g) => g.label).join(', ')}';
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          for (final g in grades)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: ReadinessVisuals.gradeColor(theme, g),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
