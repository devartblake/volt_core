import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_providers.dart';
import 'package:voltcore/shared/widgets/widgets.dart';

import '../readiness_fixtures.dart';
import 'readiness_ui_harness.dart';

void main() {
  captureOverflows();

  group('overview', () {
    testWidgets('shows the numbers, with donut and chart semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReadiness(tester);

      expect(find.text('As of 10:00 AM'), findsOneWidget);
      expect(find.text('42% ready'), findsOneWidget);
      expect(find.text('12 generators'), findsOneWidget);
      expect(find.byKey(const Key('overdue-count')), findsOneWidget);
      expect(find.text('2 overdue'), findsOneWidget);

      for (final e in {'ready': '5', 'dueSoon': '3', 'attention': '2', 'notReady': '2'}.entries) {
        expect(
          find.descendant(of: find.byKey(Key('stat-${e.key}')), matching: find.text(e.value)),
          findsOneWidget,
          reason: e.key,
        );
      }

      expect(
        find.bySemanticsLabel(RegExp(r'Fleet readiness: 42% ready\. 5 ready, 3 due soon, '
            r'2 needs attention, 2 not ready, out of 12 generators')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'Inspections due by week\. 2 overdue')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Last inspection grades: 10 Green, 1 Amber, 1 Red')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('lists the five worst units first', (tester) async {
      final c = await pumpReadiness(tester);
      expect(find.text('Needs attention first'), findsOneWidget);
      final worst = c.read(readinessSummaryProvider).value!.worstUnits;
      expect(worst, hasLength(5));
      for (final u in worst) {
        expect(find.byKey(Key('worst-${u.key}')), findsOneWidget);
      }
    });

    testWidgets('tapping a stat card applies, and a second tap removes, the filter',
        (tester) async {
      final c = await pumpReadiness(tester);
      await tester.tap(find.byKey(const Key('stat-notReady')));
      await settle(tester, 2);
      expect(c.read(readinessFilterProvider).statuses, {ReadinessStatus.notReady});
      expect(find.text('Showing 2 of 12 units'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stat-attention')));
      await settle(tester, 2);
      expect(find.text('Showing 4 of 12 units'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stat-notReady')));
      await tester.tap(find.byKey(const Key('stat-attention')));
      await settle(tester, 2);
      expect(c.read(readinessFilterProvider).isEmpty, isTrue);
      expect(find.text('12 units'), findsOneWidget);
    });

    testWidgets('tapping a due bar filters to that week; Overdue bar to overdue',
        (tester) async {
      final c = await pumpReadiness(tester);

      // Bar 0 is Overdue, bar 1 this week (Mon 2 Nov), bar 2 next week.
      await tester.tap(find.byKey(const Key('due-bar-2')));
      await settle(tester, 2);
      expect(c.read(readinessFilterProvider).dueWeekStart, DateTime(2026, 11, 9));
      expect(find.text('Showing 1 of 12 units'), findsOneWidget);
      expect(find.text('Due week of 9 Nov'), findsOneWidget);

      await tester.tap(find.byKey(const Key('due-bar-0')));
      await settle(tester, 2);
      final f = c.read(readinessFilterProvider);
      expect(f.dueWindow, ReadinessDueWindow.overdue);
      expect(f.dueWeekStart, isNull);
      expect(find.text('Showing 2 of 12 units'), findsOneWidget);
    });

    testWidgets('refresh button re-reads the inputs', (tester) async {
      var loads = 0;
      await pumpReadiness(tester, source: () {
        loads++;
        return fleetInputs();
      });
      expect(loads, 1);
      await tester.tap(find.byTooltip('Refresh'));
      await settle(tester);
      expect(loads, 2);
    });
  });

  group('filters and sort', () {
    testWidgets('search narrows the list', (tester) async {
      final c = await pumpReadiness(tester);
      await tester.enterText(find.byKey(const Key('readiness-search')), 'x_003');
      await settle(tester, 2);
      expect(find.text('Showing 1 of 12 units'), findsOneWidget);
      expect(c.read(filteredReadinessUnitsProvider).value!.single.serial, 'S3');

      await tester.tap(find.byTooltip('Clear search'));
      await settle(tester, 2);
      expect(find.text('12 units'), findsOneWidget);
    });

    testWidgets('status chips are multi-select, with a count and Clear all',
        (tester) async {
      final c = await pumpReadiness(tester);
      await tapVisible(tester, find.byKey(const Key('status-chip-dueSoon')));
      await tapVisible(tester, find.byKey(const Key('status-chip-ready')));
      expect(find.text('Showing 8 of 12 units'), findsOneWidget);
      expect(find.text('Clear all (1)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('readiness-search')), 'kohler');
      await settle(tester, 2);
      expect(find.text('Clear all (2)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-filters')));
      await settle(tester, 2);
      expect(c.read(readinessFilterProvider).isEmpty, isTrue);
    });

    testWidgets('sort menu changes the order', (tester) async {
      final c = await pumpReadiness(tester);
      expect(c.read(filteredReadinessUnitsProvider).value!.first.serial, 'S2');

      await tester.tap(find.byKey(const Key('readiness-sort')));
      await settle(tester, 3);
      for (final label in ['Worst first', 'Next due', 'Last inspected', 'Name']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('Name'), warnIfMissed: false);
      await settle(tester, 3);
      expect(c.read(readinessSortProvider), ReadinessSort.title);
      expect(c.read(filteredReadinessUnitsProvider).value!.first.title, 'Cat C9');
    });

    testWidgets('on a phone the other filters collapse into a Filters sheet',
        (tester) async {
      final c = await pumpReadiness(tester);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byKey(const Key('window-overdue')), findsNothing);

      await tester.tap(find.byKey(const Key('filters-button')));
      await settle(tester, 4);
      expect(find.byKey(const Key('window-overdue')), findsOneWidget);
      expect(find.text('Queens'), findsOneWidget);
      expect(find.text('Bronx'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('grade-red')));
      await tapVisible(tester, find.byKey(const Key('window-next90')));
      expect(c.read(readinessFilterProvider).grade, ReadinessGrade.red);
      expect(c.read(readinessFilterProvider).dueWindow, ReadinessDueWindow.next90);

      await tapVisible(tester, find.text('Done'));
      expect(find.text('Filters (2)'), findsOneWidget);
    });

    testWidgets('has-follow-ups toggle and make dropdown', (tester) async {
      final c = await pumpReadiness(tester, size: const Size(1000, 2400));
      // Wide enough for the inline controls.
      await scrollTo(tester, find.byKey(const Key('followups-switch')));
      await tester.tap(find.byKey(const Key('followups-switch')));
      await settle(tester, 2);
      expect(c.read(filteredReadinessUnitsProvider).value!.map((u) => u.serial), ['S4']);
    });

    testWidgets('borough chips are hidden when no site code gives a borough',
        (tester) async {
      await pumpReadiness(tester, inputs: ReadinessInputs(inspections: [
        insp('z1', serial: 'Z1', site: 'ABC-1', dueIn: 60),
        insp('z2', serial: 'Z2', site: 'ABC-2', dueIn: 70),
      ]));
      await tester.tap(find.byKey(const Key('filters-button')));
      await settle(tester, 4);
      expect(find.text('Borough'), findsNothing);
      expect(find.byKey(const Key('window-overdue')), findsOneWidget);
    });

    testWidgets('filters and sort are remembered for the session', (tester) async {
      final c = await pumpReadiness(tester);
      await tester.tap(find.byKey(const Key('stat-notReady')));
      c.read(readinessSortProvider.notifier).state = ReadinessSort.nextDue;
      await settle(tester, 2);

      await tester.pumpWidget(const SizedBox()); // leave the screen
      expect(c.read(readinessFilterProvider).statuses, {ReadinessStatus.notReady});
      expect(c.read(readinessSortProvider), ReadinessSort.nextDue);
    });

    testWidgets('opened from the dashboard link with ?status=notReady', (tester) async {
      final c = await pumpReadiness(tester, initialStatus: 'notReady');
      expect(c.read(readinessFilterProvider).statuses, {ReadinessStatus.notReady});
      expect(find.text('Showing 2 of 12 units'), findsOneWidget);
    });
  });

  group('segments', () {
    testWidgets('Units shows cards with status, reasons and due text', (tester) async {
      final c = await pumpReadiness(tester, size: const Size(390, 2600));
      final s3 = unitKey(c, 'S3');
      await scrollTo(tester, find.byKey(ValueKey('unit-$s3')));
      expect(find.text('Overdue 45 days'), findsOneWidget);
      expect(find.text('Overdue 10 days'), findsOneWidget);
      expect(find.text('Inspection overdue by 10 days'), findsWidgets);
    });

    testWidgets('Due calendar groups units by week with counts', (tester) async {
      await pumpReadiness(tester, size: const Size(390, 2600));
      await tapVisible(tester, find.text('Due calendar'));
      await scrollTo(tester, find.text('Overdue (2)'));
      expect(find.text('Overdue (2)'), findsOneWidget);
      await scrollTo(tester, find.text('Next week (1)'));
      expect(find.text('Next week (1)'), findsOneWidget);
    });

    testWidgets('Follow-ups lists units with their notes', (tester) async {
      await pumpReadiness(tester, size: const Size(390, 2600));
      await tapVisible(tester, find.textContaining('Follow-ups'));
      await scrollTo(tester, find.textContaining('Replace transfer switch relay'));
      expect(find.textContaining('Replace transfer switch relay'), findsOneWidget);
    });

    testWidgets('Parts lists units short of parts with a Shortages link', (tester) async {
      await pumpReadiness(tester, size: const Size(390, 2600));
      await tapVisible(tester, find.textContaining('Parts ('));
      await scrollTo(tester, find.byKey(const Key('open-shortages')));
      expect(find.text('3 parts short for the next job'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final never = Completer<ReadinessInputs>();
      await pumpReadiness(tester, pending: never.future);
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('no generators explains where readiness comes from', (tester) async {
      await pumpReadiness(tester, inputs: const ReadinessInputs());
      expect(find.text('No generators yet'), findsOneWidget);
      expect(find.textContaining('worked out from inspections'), findsOneWidget);
    });

    testWidgets('no match offers Clear filters', (tester) async {
      final c = await pumpReadiness(tester, size: const Size(390, 2600));
      await tester.enterText(find.byKey(const Key('readiness-search')), 'zzzz-nothing');
      await settle(tester, 2);
      await scrollTo(tester, find.text('No units match these filters'));
      await tester.tap(find.byKey(const Key('empty-clear-filters')));
      await settle(tester, 2);
      expect(c.read(readinessFilterProvider).isEmpty, isTrue);
      expect(find.text('No units match these filters'), findsNothing);
    });

    testWidgets('an error with no data offers Retry', (tester) async {
      await pumpReadiness(tester, inputsError: StateError('offline'));
      expect(find.text('Could not load fleet readiness'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the last data under an error banner',
        (tester) async {
      var fail = false;
      await pumpReadiness(tester, source: () {
        if (fail) throw StateError('offline');
        return fleetInputs();
      });
      expect(find.text('42% ready'), findsOneWidget);

      fail = true;
      await tester.tap(find.byTooltip('Refresh'));
      await settle(tester);
      expect(find.text('Could not refresh. Showing the last result.'), findsOneWidget);
      expect(find.text('42% ready'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Could not refresh. Showing the last result.'), findsNothing);
    });

    testWidgets('unmatched records are counted, with an info sheet', (tester) async {
      await pumpReadiness(tester,
          inputs: ReadinessInputs(
            inspections: [insp('i1', serial: 'S1', site: 'Q_001', dueIn: 60)],
            maintenance: [
              const ReadinessMaintenance(id: 'orphan', siteCode: 'NOWHERE', requiresFollowUp: true),
            ],
          ));
      expect(find.text('1 record could not be matched to a generator'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unmatched-note')));
      await settle(tester, 4);
      expect(find.text('Records not matched'), findsOneWidget);
      expect(find.text('1 maintenance records'), findsOneWidget);
    });
  });
}
