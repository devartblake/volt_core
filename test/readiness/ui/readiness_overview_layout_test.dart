import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_providers.dart';
import 'package:voltcore/modules/readiness/presenter/widgets/readiness_attention_row.dart';
import 'package:voltcore/modules/readiness/presenter/widgets/readiness_mini_charts.dart';

import '../readiness_fixtures.dart';
import 'readiness_ui_harness.dart';

const _sizes = <String, Size>{
  'phone 360x800': Size(360, 800),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

Finder _titled(String t) => find.text(t);

/// Needs-dates-free fleet: only a registered generator that was never inspected.
ReadinessInputs _noDates() => const ReadinessInputs(
      equipment: [ReadinessEquipment(id: 'e1', serial: 'N1', make: 'Kohler', model: '100')],
    );

void main() {
  captureOverflows();

  group('layout', () {
    testWidgets('Due by week and grade share a row on a tablet, attention row below',
        (tester) async {
      await pumpReadiness(tester, size: const Size(800, 2600));
      final due = tester.getRect(_titled('Due by week'));
      final grade = tester.getRect(_titled('Last inspection grade'));
      final attention = tester.getRect(_titled('Needs attention first'));
      expect((due.top - grade.top).abs(), lessThan(2));
      expect(grade.left, greaterThan(due.left + 200));
      expect(attention.top, greaterThan(due.bottom));
      // Under the row, not beside the grade card.
      expect(attention.left, lessThan(due.left + 40));
    });

    testWidgets('on a phone the cards stack and the attention row scrolls sideways',
        (tester) async {
      await pumpReadiness(tester, size: const Size(360, 2600));
      final due = tester.getRect(_titled('Due by week'));
      final grade = tester.getRect(_titled('Last inspection grade'));
      final attention = tester.getRect(_titled('Needs attention first'));
      expect(grade.top, greaterThan(due.top + 100));
      expect(attention.top, greaterThan(grade.top));

      final list = find.byKey(const Key('worst-list'));
      expect(list, findsOneWidget);
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)));
      expect(scroll.position.axis, Axis.horizontal);
      expect(scroll.position.maxScrollExtent, greaterThan(0));

      // The last card is reachable by dragging the row.
      final c = tester.element(list);
      expect(c, isNotNull);
      await tester.drag(list, const Offset(-1200, 0));
      await settle(tester, 3);
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
    });

    testWidgets('when all five fit they fill the row without scrolling', (tester) async {
      tester.view.physicalSize = const Size(1600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpReadiness(tester, size: const Size(1600, 2600));
      final worst = c.read(readinessSummaryProvider).value!.worstUnits;
      var opened = '';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            child: ReadinessAttentionRow(
                units: worst, onOpen: (u) => opened = u.key, onSeeAll: () {}),
          ),
        ),
      ));
      expect(find.byKey(const Key('worst-list')), findsNothing);
      final lefts = [
        for (final u in worst) tester.getRect(find.byKey(Key('worst-${u.key}'))).left
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
      expect(tester.getRect(find.byKey(Key('worst-${worst.last.key}'))).right,
          lessThanOrEqualTo(1600));
      await tester.tap(find.byKey(Key('worst-${worst[1].key}')));
      expect(opened, worst[1].key);
    });

    testWidgets('See all applies the Not ready filter', (tester) async {
      final c = await pumpReadiness(tester);
      await tapVisible(tester, find.byKey(const Key('worst-see-all')));
      final f = c.read(readinessFilterProvider);
      expect(f.statuses, {ReadinessStatus.notReady});
    });
  });

  group('due by week states', () {
    testWidgets('keeps the chart and tap-a-bar when bars exist', (tester) async {
      final c = await pumpReadiness(tester);
      expect(find.byKey(const Key('due-empty')), findsNothing);
      await tapVisible(tester, find.byKey(const Key('due-bar-0')));
      expect(c.read(readinessFilterProvider).dueWindow, ReadinessDueWindow.overdue);
    });

    testWidgets('shows a friendly note when no unit has a due date', (tester) async {
      await pumpReadiness(tester, inputs: _noDates());
      expect(find.byKey(const Key('due-empty')), findsOneWidget);
      expect(find.text('No next-inspection dates set yet. Due dates shown are estimates.'),
          findsOneWidget);
      expect(find.byKey(const Key('due-bar-0')), findsNothing);
    });

    testWidgets('names the estimated count when everything is due later', (tester) async {
      await pumpReadiness(tester,
          inputs: ReadinessInputs(inspections: [insp('a', serial: 'A', ago: 10)]));
      expect(find.byKey(const Key('due-empty')), findsOneWidget);
      expect(find.text('1 generator has an estimated due date'), findsOneWidget);
      expect(find.text('1 due later'), findsOneWidget);
    });
  });

  group('tile graphs', () {
    testWidgets('every status tile and the hero carry a described graph', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReadiness(tester);
      expect(find.bySemanticsLabel(RegExp(r'^5 of 12 generators, 42% of the fleet')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Due in the next 12 weeks: \d+, \d+ of them within')),
          findsOneWidget);
      // Attention: S3 overdue 10 days + 3 parts short, S4 amber + follow-up.
      expect(
          find.bySemanticsLabel(
              RegExp(r'^Reasons: 1 Amber grade, 1 Overdue, 1 Follow-ups, 1 Parts short$')),
          findsOneWidget);
      // Not ready: S1 red, S2 long overdue.
      expect(find.bySemanticsLabel(RegExp(r'^Reasons: 1 Red grade, 1 Long overdue$')),
          findsOneWidget);
      expect(find.bySemanticsLabel('2 of 12 generators overdue'), findsOneWidget);
      expect(find.byType(MiniRing), findsOneWidget);
      expect(find.byType(MiniBarStrip), findsOneWidget);
      handle.dispose();
    });

    testWidgets('all-zero data still paints (empty fleet inputs)', (tester) async {
      await pumpReadiness(tester, inputs: _noDates());
      expect(find.byType(MiniRing), findsOneWidget);
      expect(find.byType(MiniStackBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    for (final w in [0.0, 3.0, 20.0]) {
      testWidgets('mini charts survive a ${w}px box', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: w,
              height: w,
              child: Column(children: const [
                Expanded(child: MiniRing(fraction: 0.5, color: Colors.green, semanticLabel: 'r')),
                Expanded(
                    child: MiniBarStrip(
                        values: [0, 1, 2],
                        highlighted: [true, false, true],
                        color: Colors.blue,
                        semanticLabel: 'b')),
                Expanded(
                    child: MiniStackBar(
                        segments: [MiniSegment(0, Colors.red), MiniSegment(0, Colors.blue)],
                        semanticLabel: 's')),
              ]),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final dark in [false, true]) {
    for (final e in _sizes.entries) {
      for (final noDates in [false, true]) {
        testWidgets(
            'overview fits at 1.3x text: ${e.key}, ${dark ? 'dark' : 'light'}'
            '${noDates ? ', no due dates' : ''}', (tester) async {
          await pumpReadiness(
            tester,
            size: e.value,
            textScale: 1.3,
            brightness: dark ? Brightness.dark : Brightness.light,
            inputs: noDates ? _noDates() : null,
          );
          for (var i = 0; i < 3; i++) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
            await settle(tester, 2);
          }
          final list = find.byKey(const Key('worst-list'));
          if (list.evaluate().isNotEmpty) {
            await tester.drag(list, const Offset(-600, 0));
            await settle(tester, 2);
          }
          expect(overflows, isEmpty,
              reason: overflows.map((d) => d.exceptionAsString()).join('\n'));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
