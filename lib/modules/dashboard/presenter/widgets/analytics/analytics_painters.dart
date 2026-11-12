import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Painters for the Analytics graphs. They take resolved colours (from
/// `ColorScheme` / `theme.status`) and never read the theme themselves, so
/// they repaint correctly when the theme switches.

/// X-axis labels shared by the bar and line charts.
class AxisLabels {
  const AxisLabels({
    required this.labels,
    required this.style,
    required this.scaler,
    required this.direction,
  });

  /// One label per slot.
  final List<String> labels;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;

  /// Height to reserve under the plot for one line of labels.
  static double heightFor(TextStyle style, TextScaler scaler) =>
      scaler.scale(style.fontSize ?? 12) * (style.height ?? 1.3) + 6;

  /// Paints as many labels as fit without touching, always including the last.
  void paint(Canvas canvas, Size size, List<double> centers, double top) {
    if (labels.isEmpty) return;
    final painters = [
      for (final l in labels)
        TextPainter(
          text: TextSpan(text: l, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout(),
    ];
    final widest = painters.map((p) => p.width).reduce(math.max);
    final slot = centers.length > 1 ? (centers[1] - centers[0]).abs() : size.width;
    final stride = math.max(1, ((widest + 6) / slot).ceil());
    for (var i = 0; i < painters.length; i++) {
      if ((painters.length - 1 - i) % stride != 0) continue;
      final p = painters[i];
      final x = (centers[i] - p.width / 2)
          .clamp(0.0, math.max(0.0, size.width - p.width))
          .toDouble();
      p.paint(canvas, Offset(x, top + 3));
    }
  }
}

/// Vertical bars with a baseline and a faint mid gridline.
class BarChartPainter extends CustomPainter {
  BarChartPainter({
    required this.values,
    required this.barColor,
    required this.selectedColor,
    required this.gridColor,
    required this.highlightColor,
    required this.axis,
    required this.axisHeight,
    this.selected,
  });

  final List<int> values;
  final Color barColor;
  final Color selectedColor;
  final Color gridColor;
  final Color highlightColor;
  final AxisLabels axis;
  final double axisHeight;
  final int? selected;

  static const double _topPad = 6;

  /// Slot index under [dx], or null when there are no values.
  static int? indexAt(double dx, double width, int count) {
    if (count == 0 || width <= 0) return null;
    return (dx / width * count).floor().clamp(0, count - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final plotH = math.max(1.0, size.height - axisHeight - _topPad);
    final base = _topPad + plotH;
    final maxV = math.max(1, values.reduce(math.max));
    final slot = size.width / n;
    final barW = (slot * 0.62).clamp(2.0, 28.0).toDouble();

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, _topPad + plotH / 2), Offset(size.width, _topPad + plotH / 2), grid);
    canvas.drawLine(Offset(0, base), Offset(size.width, base), grid..strokeWidth = 1.5);

    final centers = <double>[];
    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 0.5);
      centers.add(cx);
      final isSel = selected == i;
      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(slot * i, 0, slot, base),
            const Radius.circular(4),
          ),
          Paint()..color = highlightColor,
        );
      }
      final h = values[i] <= 0 ? 0.0 : math.max(3.0, plotH * values[i] / maxV);
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, base - h, barW, h),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = isSel ? selectedColor : barColor,
        );
      }
    }
    axis.paint(canvas, size, centers, base);
  }

  @override
  bool shouldRepaint(BarChartPainter old) =>
      old.selected != selected ||
      old.barColor != barColor ||
      old.selectedColor != selectedColor ||
      old.gridColor != gridColor ||
      old.highlightColor != highlightColor ||
      old.axisHeight != axisHeight ||
      old.axis.labels.length != axis.labels.length ||
      !_same(old.values, values);
}

/// Line with a soft area fill and a dot per point.
class LinePainter extends CustomPainter {
  LinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.surfaceColor,
    required this.axis,
    required this.axisHeight,
    this.selected,
  });

  final List<int> values;
  final Color lineColor;
  final Color gridColor;

  /// Fill inside the dots, so they read as rings on any surface.
  final Color surfaceColor;
  final AxisLabels axis;
  final double axisHeight;
  final int? selected;

  static const double _pad = 8;

  /// Points are centred in equal slots, like the bar chart.
  static List<Offset> pointsFor(List<int> values, Size size, double axisHeight) {
    final n = values.length;
    if (n == 0) return const [];
    final plotH = math.max(1.0, size.height - axisHeight - _pad * 2);
    final maxV = math.max(1, values.reduce(math.max));
    final slot = size.width / n;
    return [
      for (var i = 0; i < n; i++)
        Offset(slot * (i + 0.5), _pad + plotH - plotH * values[i] / maxV),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = pointsFor(values, size, axisHeight);
    if (pts.isEmpty) return;
    final plotH = math.max(1.0, size.height - axisHeight - _pad * 2);
    final base = _pad + plotH;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, _pad + plotH / 2), Offset(size.width, _pad + plotH / 2), grid);
    canvas.drawLine(Offset(0, base), Offset(size.width, base), grid..strokeWidth = 1.5);

    if (pts.length > 1) {
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      final area = Path.from(line)
        ..lineTo(pts.last.dx, base)
        ..lineTo(pts.first.dx, base)
        ..close();
      canvas.drawPath(area, Paint()..color = lineColor.withValues(alpha: 0.14));
      canvas.drawPath(
        line,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < pts.length; i++) {
      final isSel = selected == i;
      final r = isSel ? 5.0 : 3.0;
      canvas.drawCircle(pts[i], r + 1.5, Paint()..color = surfaceColor);
      canvas.drawCircle(pts[i], r, Paint()..color = lineColor);
    }
    axis.paint(canvas, size, [for (final p in pts) p.dx], base);
  }

  @override
  bool shouldRepaint(LinePainter old) =>
      old.selected != selected ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.surfaceColor != surfaceColor ||
      old.axisHeight != axisHeight ||
      !_same(old.values, values);
}

/// One slice of a [DonutPainter].
class DonutSlice {
  const DonutSlice(this.value, this.color);

  final double value;
  final Color color;
}

/// Ring split into slices, starting at 12 o'clock. A thin gap separates
/// slices so neighbours stay distinct without relying on colour alone.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.slices,
    required this.trackColor,
    this.strokeRatio = 0.2,
  });

  final List<DonutSlice> slices;
  final Color trackColor;
  final double strokeRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final stroke = side * strokeRatio;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side - stroke,
      height: side - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
      return;
    }
    final shown = slices.where((s) => s.value > 0).length;
    final gap = shown > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(rect, start + gap / 2, math.max(0.001, sweep - gap), false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.trackColor != trackColor ||
      old.strokeRatio != strokeRatio ||
      old.slices.length != slices.length ||
      [for (var i = 0; i < slices.length; i++) i]
          .any((i) => old.slices[i].value != slices[i].value || old.slices[i].color != slices[i].color);
}

/// One horizontal bar: a rounded track with a filled part ([fraction] 0..1).
/// Rows of these (label, bar, count) make a horizontal bar chart; the label
/// and count are real text so they scale and wrap with the user's text size.
class HorizontalBarsPainter extends CustomPainter {
  HorizontalBarsPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = trackColor);
    final f = fraction.clamp(0.0, 1.0).toDouble();
    if (f <= 0) return;
    final w = math.max(size.height, size.width * f);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(HorizontalBarsPainter old) =>
      old.fraction != fraction || old.color != color || old.trackColor != trackColor;
}

/// A single 100% bar split into coloured segments, with [gapColor] gaps.
class StackedBarPainter extends CustomPainter {
  StackedBarPainter({
    required this.slices,
    required this.trackColor,
    required this.gapColor,
  });

  final List<DonutSlice> slices;
  final Color trackColor;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final clip = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(Offset.zero & size, Paint()..color = trackColor);
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total > 0) {
      var x = 0.0;
      for (final s in slices) {
        if (s.value <= 0) continue;
        final w = size.width * s.value / total;
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), Paint()..color = s.color);
        x += w;
        if (x < size.width - 0.5) {
          canvas.drawRect(Rect.fromLTWH(x - 1, 0, 2, size.height), Paint()..color = gapColor);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StackedBarPainter old) =>
      old.trackColor != trackColor ||
      old.gapColor != gapColor ||
      old.slices.length != slices.length ||
      [for (var i = 0; i < slices.length; i++) i]
          .any((i) => old.slices[i].value != slices[i].value || old.slices[i].color != slices[i].color);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
