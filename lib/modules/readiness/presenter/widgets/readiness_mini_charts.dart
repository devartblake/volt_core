import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../domain/readiness_mini_series.dart';
import '../../domain/readiness_models.dart';
import 'readiness_visuals.dart';

/// Small graphs for the readiness number cards. All are drawn with
/// [CustomPainter] (no chart package), carry one Semantics label, use the
/// theme's status colours, and fall back to a flat track when the data is all
/// zero or the box is tiny.

/// One coloured piece of a [MiniStackBar].
class MiniSegment {
  const MiniSegment(this.value, this.color);

  final int value;
  final Color color;
}

/// Colour of a reason slice on the Attention / Not ready tiles.
Color miniReasonColor(ThemeData theme, ReadinessStatus status, ReadinessReasonKind kind) {
  final scheme = theme.colorScheme;
  return switch (kind) {
    ReadinessReasonKind.amberGrade => theme.status.warning,
    ReadinessReasonKind.redGrade => scheme.error,
    ReadinessReasonKind.overdue => status == ReadinessStatus.notReady
        ? scheme.error.withValues(alpha: 0.6)
        : scheme.error,
    ReadinessReasonKind.followUps => theme.status.info,
    ReadinessReasonKind.partsShort => scheme.onSurfaceVariant,
    ReadinessReasonKind.neverInspected => scheme.outline,
    _ => scheme.outline,
  };
}

/// "Reasons: 2 Amber grade, 1 Overdue" for a screen reader.
String reasonSemantics(String title, List<ReasonCount> reasons) {
  final parts = [
    for (final r in reasons)
      if (r.count > 0) '${r.count} ${r.label}',
  ];
  return parts.isEmpty ? '$title: none' : '$title: ${parts.join(', ')}';
}

/// A ring showing [fraction] (0..1) of a whole in [color].
class MiniRing extends StatelessWidget {
  const MiniRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.semanticLabel,
    this.size = 34,
  });

  final double fraction;
  final Color color;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: MiniRingPainter(
              fraction: fraction.clamp(0.0, 1.0), color: color, track: track),
        ),
      ),
    );
  }
}

class MiniRingPainter extends CustomPainter {
  MiniRingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side < 6) return;
    final stroke = math.max(3.0, side * 0.2);
    final rect = Rect.fromLTWH((size.width - side) / 2, (size.height - side) / 2, side, side)
        .deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, p);
    if (fraction <= 0) return;
    p
      ..color = color
      ..strokeCap = fraction >= 1 ? StrokeCap.butt : StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, p);
  }

  @override
  bool shouldRepaint(MiniRingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// A strip of small bars, one per value; bars with [highlighted] true use
/// [color], the others a muted tone. All zero gives a flat baseline.
class MiniBarStrip extends StatelessWidget {
  const MiniBarStrip({
    super.key,
    required this.values,
    required this.highlighted,
    required this.color,
    required this.semanticLabel,
    this.height = 30,
  });

  final List<int> values;
  final List<bool> highlighted;
  final Color color;
  final String semanticLabel;
  final double height;

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
          painter: MiniBarsPainter(
            values: values,
            highlighted: highlighted,
            color: color,
            muted: scheme.outlineVariant,
            baseline: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class MiniBarsPainter extends CustomPainter {
  MiniBarsPainter({
    required this.values,
    required this.highlighted,
    required this.color,
    required this.muted,
    required this.baseline,
  });

  final List<int> values;
  final List<bool> highlighted;
  final Color color;
  final Color muted;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0 || size.width < n || size.height < 4) return;
    final maxV = values.fold<int>(0, math.max);
    final slot = size.width / n;
    final barW = math.max(1.0, slot * 0.66);
    final base = size.height;
    for (var i = 0; i < n; i++) {
      final on = i < highlighted.length && highlighted[i];
      final h = maxV == 0 || values[i] == 0
          ? 2.0
          : math.max(4.0, (size.height - 2) * values[i] / maxV);
      final x = slot * i + (slot - barW) / 2;
      final paint = Paint()
        ..color = values[i] == 0 ? baseline : (on ? color : muted);
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, base - h, barW, h),
            topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MiniBarsPainter old) =>
      old.values.toString() != values.toString() ||
      old.highlighted.toString() != highlighted.toString() ||
      old.color != color ||
      old.muted != muted ||
      old.baseline != baseline;
}

/// One horizontal bar split into [segments]. All zero gives an empty track.
class MiniStackBar extends StatelessWidget {
  const MiniStackBar({
    super.key,
    required this.segments,
    required this.semanticLabel,
    this.height = 10,
  });

  final List<MiniSegment> segments;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: MiniStackPainter(segments: segments, track: track)),
      ),
    );
  }
}

class MiniStackPainter extends CustomPainter {
  MiniStackPainter({required this.segments, required this.track});

  final List<MiniSegment> segments;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 4 || size.height < 2) return;
    final r = Radius.circular(size.height / 2);
    final clip = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final total = segments.fold<int>(0, (a, s) => a + math.max(0, s.value));
    if (total > 0) {
      var x = 0.0;
      final shown = segments.where((s) => s.value > 0).length;
      for (final s in segments) {
        if (s.value <= 0) continue;
        final w = size.width * s.value / total;
        // A thin gap between pieces, none for a single piece.
        final gap = shown > 1 ? 1.5 : 0.0;
        canvas.drawRect(
            Rect.fromLTWH(x, 0, math.max(1.0, w - gap), size.height),
            Paint()..color = s.color);
        x += w;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MiniStackPainter old) =>
      old.track != track ||
      old.segments.length != segments.length ||
      [for (var i = 0; i < segments.length; i++) i].any((i) =>
          old.segments[i].value != segments[i].value ||
          old.segments[i].color != segments[i].color);
}

/// The graph for one status tile (the series are computed by the caller from
/// the summary and units).
class ReadinessTileGraph extends StatelessWidget {
  const ReadinessTileGraph({
    super.key,
    required this.status,
    required this.share,
    required this.dueWeeks,
    required this.reasons,
    required this.total,
    required this.count,
  });

  final ReadinessStatus status;

  /// Share of the fleet with this status (0..1).
  final double share;

  /// Due-by-week slice (used for Due soon).
  final List<DueWeekPoint> dueWeeks;

  /// Reason breakdown (used for Attention and Not ready).
  final List<ReasonCount> reasons;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ReadinessVisuals.statusColor(theme, status);
    switch (status) {
      case ReadinessStatus.ready:
        return Align(
          alignment: Alignment.centerRight,
          child: MiniRing(
            fraction: share,
            color: color,
            semanticLabel: total == 0
                ? 'No generators'
                : '$count of $total generators, ${(share * 100).round()}% of the fleet',
          ),
        );
      case ReadinessStatus.dueSoon:
        final sum = dueWeeks.fold<int>(0, (a, p) => a + p.count);
        final inWindow =
            dueWeeks.where((p) => p.inWindow).fold<int>(0, (a, p) => a + p.count);
        return MiniBarStrip(
          values: [for (final p in dueWeeks) p.count],
          highlighted: [for (final p in dueWeeks) p.inWindow],
          color: color,
          semanticLabel: 'Due in the next ${dueWeeks.length} weeks: $sum, '
              '$inWindow of them within the due soon window',
        );
      case ReadinessStatus.attention:
      case ReadinessStatus.notReady:
        return Align(
          alignment: Alignment.centerRight,
          child: MiniStackBar(
            segments: [
              for (final r in reasons)
                MiniSegment(r.count, miniReasonColor(theme, status, r.kind)),
            ],
            semanticLabel: reasonSemantics('Reasons', reasons),
          ),
        );
    }
  }
}
