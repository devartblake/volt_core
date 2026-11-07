import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/dashboard/domain/inspection_trend.dart';
import 'package:voltcore/modules/dashboard/presenter/widgets/trend_sparkline.dart';
import 'package:voltcore/shared/widgets/stat_card.dart';

final _now = DateTime(2026, 11, 7, 15);

void main() {
  group('dailyCounts', () {
    test('buckets by calendar day, oldest first, today last', () {
      final counts = dailyCounts([
        DateTime(2026, 11, 7, 0, 5), // today
        DateTime(2026, 11, 7, 23, 59), // today
        DateTime(2026, 11, 5, 9), // 2 days ago
        DateTime(2026, 11, 1, 9), // 6 days ago (oldest bucket)
      ], now: _now);
      expect(counts, [1, 0, 0, 0, 1, 0, 2]);
    });

    test('ignores dates outside the window and in the future', () {
      final counts = dailyCounts([
        DateTime(2026, 10, 31, 23), // 7 days ago: outside
        DateTime(2026, 11, 8, 1), // tomorrow
      ], now: _now);
      expect(counts, List.filled(7, 0));
    });

    test('empty input gives zeros; length follows days', () {
      expect(dailyCounts(const [], now: _now), List.filled(7, 0));
      expect(dailyCounts([_now], now: _now, days: 3), [0, 0, 1]);
    });

    test('is stable across a DST change', () {
      // Clocks change in the US on 2026-11-01.
      final counts =
          dailyCounts([DateTime(2026, 11, 1, 12)], now: DateTime(2026, 11, 3));
      expect(counts, [0, 0, 0, 0, 1, 0, 0]);
    });

    test('label reads as a sentence', () {
      expect(trendSemanticLabel('Inspections', [1, 0, 2]),
          'Inspections per day, last 3 days: 1, 0, 2');
    });
  });

  test('sparkline points: flat zeros sit on the bottom, peak on top', () {
    const size = Size(100, 20);
    final flat = SparklinePainter.pointsFor([0, 0, 0], size);
    expect(flat.map((p) => p.dy).toSet().length, 1);
    final pts = SparklinePainter.pointsFor([0, 4, 2], size);
    expect(pts[1].dy, lessThan(pts[2].dy));
    expect(pts[2].dy, lessThan(pts[0].dy));
    expect(pts.first.dx, lessThan(pts.last.dx));
    expect(SparklinePainter.pointsFor(const [], size), isEmpty);
  });

  const sizes = {
    'phone': Size(360, 800),
    'tablet': Size(1000, 800),
  };
  for (final e in sizes.entries) {
    testWidgets('stat tile with sparkline at 1.3x on a ${e.key}',
        (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) {
          overflows.add(d.toString());
        } else {
          previous?.call(d);
        }
      };
      final counts = [1, 0, 2, 0, 0, 3, 1];
      final cols = e.value.width >= 700 ? 4 : 2;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          // Same cell height the dashboard grid uses at 1.3x with a trend.
          body: GridView(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 136.0 * 1.3 + TrendSparkline.extraHeight,
            ),
            padding: const EdgeInsets.all(16),
            children: [
              StatCard(
                compact: true,
                icon: Icons.fact_check_outlined,
                label: 'Inspections, 7 days',
                value: '7',
                footerSemantics: trendSemanticLabel('Inspections', counts),
                footer: TrendSparkline.inspections(counts: counts),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      FlutterError.onError = previous;

      expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
      expect(find.byType(TrendSparkline), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(StatCard)).label,
        contains('Inspections per day, last 7 days: 1, 0, 2, 0, 0, 3, 1'),
      );
    });
  }
}
