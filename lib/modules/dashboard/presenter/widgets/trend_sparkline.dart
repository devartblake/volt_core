import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/inspection_trend.dart';

/// Small line chart of [values] (oldest first) for a stat tile.
///
/// Drawn with a [CustomPainter]; announced to screen readers as one
/// [semanticLabel] rather than as individual points.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    super.key,
    required this.values,
    required this.semanticLabel,
    this.color,
    this.height = 20,
  });

  /// Convenience for the dashboard's inspections tile.
  TrendSparkline.inspections({
    Key? key,
    required List<int> counts,
    Color? color,
  }) : this(
          key: key,
          values: counts,
          color: color,
          semanticLabel: trendSemanticLabel('Inspections', counts),
        );

  final List<int> values;
  final String semanticLabel;
  final Color? color;
  final double height;

  /// Vertical room the sparkline needs, including the gap above it.
  static const double extraHeight = 20 + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: SparklinePainter(
            values: values,
            lineColor: color ?? scheme.primary,
            baselineColor: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// Paints a polyline with a dot on the latest value and a faint baseline.
class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.baselineColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color baselineColor;

  static const double _dotRadius = 2.5;

  /// Canvas points for [values] in [size], padded so the dot is not clipped.
  static List<Offset> pointsFor(List<int> values, Size size) {
    if (values.isEmpty) return const [];
    const pad = _dotRadius + 1;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV <= 0 ? 1 : maxV;
    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + (values.length == 1 ? w / 2 : w * i / (values.length - 1)),
          pad + h - h * values[i] / range,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = pointsFor(values, size);
    if (pts.isEmpty) return;

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(pts.last, _dotRadius, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.lineColor != lineColor ||
      old.baselineColor != baselineColor ||
      !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
