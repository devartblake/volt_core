import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_providers.dart';
import 'package:voltcore/modules/readiness/presenter/widgets/readiness_unit_detail.dart';

import 'readiness_ui_harness.dart';

Future<void> openWorst(WidgetTester tester, dynamic c, String serial) async {
  final card = find.byKey(Key('worst-${unitKey(c, serial)}'));
  await tester.ensureVisible(card); // the row scrolls sideways when it does not fit
  await tester.pump();
  await tester.tap(card);
  await settle(tester, 6);
}

void main() {
  captureOverflows();

  group('unit detail', () {
    testWidgets('opens a bottom sheet on a phone with every reason and the facts',
        (tester) async {
      final c = await pumpReadiness(tester, size: const Size(390, 1800));
      await openWorst(tester, c, 'S3');

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(ReadinessUnitDetail), findsOneWidget);
      expect(find.text('Why needs attention'), findsOneWidget);
      // Both reasons, with their icons.
      expect(
          find.descendant(
              of: find.byType(ReadinessUnitDetail),
              matching: find.text('Parts short for next job (3 parts)')),
          findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsWidgets);
      expect(find.byIcon(Icons.event_busy_outlined), findsWidgets);
      for (final label in ['Serial', 'Fuel', 'Last inspection', 'Next inspection due']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('S3'), findsOneWidget);
      expect(find.text('Open latest inspection'), findsOneWidget);
      expect(find.text('Open full history'), findsOneWidget);
      expect(find.text('Parts profile'), findsOneWidget);
      expect(find.text('Open Shortages'), findsOneWidget);
      expect(find.text('Inspection history'), findsOneWidget);
    });

    testWidgets('follow-up notes and the history trend show for the amber unit',
        (tester) async {
      final c = await pumpReadiness(tester, size: const Size(390, 1800));
      await openWorst(tester, c, 'S4');
      expect(find.text('Open follow-ups'), findsOneWidget);
      expect(find.textContaining('Replace transfer switch relay'), findsOneWidget);
    });

    testWidgets('two panes at 1280 wide: list left, detail right, no sheet',
        (tester) async {
      final c = await pumpReadiness(tester, size: const Size(1280, 1000));
      expect(find.text('Select a generator'), findsOneWidget);
      expect(find.byType(ReadinessUnitDetail), findsNothing);

      await openWorst(tester, c, 'S3');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ReadinessUnitDetail), findsOneWidget);
      expect(find.text('Select a generator'), findsNothing);
      final pane = tester.getRect(find.byType(ReadinessUnitDetail));
      expect(pane.left, greaterThan(700));
      expect(pane.right, lessThanOrEqualTo(1280));

      // Selecting another unit swaps the pane.
      await openWorst(tester, c, 'S2');
      expect(find.byType(ReadinessUnitDetail), findsOneWidget);
      expect(find.text('Why not ready'), findsOneWidget);
    });
  });

  group('role gating', () {
    testWidgets('technician: read-only, no schedule, bulk schedule or gear',
        (tester) async {
      final c = await pumpReadiness(tester, role: UserRole.tech, size: const Size(390, 1800));
      expect(find.byKey(const Key('readiness-settings')), findsNothing);
      await openWorst(tester, c, 'S3');
      expect(find.text('Open latest inspection'), findsOneWidget);
      expect(find.byKey(const Key('schedule-inspection')), findsNothing);
      expect(find.byKey(const Key('create-maintenance-job')), findsNothing);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await settle(tester);

      await tapVisible(tester, find.byKey(const Key('select-button')));
      expect(find.byKey(const Key('bulk-schedule')), findsNothing);
      expect(find.byKey(const Key('bulk-export')), findsOneWidget);
    });

    testWidgets('dispatcher schedules but cannot open settings', (tester) async {
      final c = await pumpReadiness(tester, role: UserRole.dispatcher, size: const Size(390, 1800));
      expect(find.byKey(const Key('readiness-settings')), findsNothing);
      await openWorst(tester, c, 'S3');
      expect(find.byKey(const Key('schedule-inspection')), findsOneWidget);
      expect(find.byKey(const Key('create-maintenance-job')), findsOneWidget);
    });

    testWidgets('supervisor schedules but has no gear', (tester) async {
      final c = await pumpReadiness(tester, role: UserRole.supervisor, size: const Size(390, 1800));
      expect(find.byKey(const Key('readiness-settings')), findsNothing);
      await openWorst(tester, c, 'S3');
      expect(find.byKey(const Key('schedule-inspection')), findsOneWidget);
    });

    testWidgets('admin has the gear', (tester) async {
      await pumpReadiness(tester, role: UserRole.admin);
      expect(find.byKey(const Key('readiness-settings')), findsOneWidget);
    });
  });

  group('scheduling', () {
    testWidgets('Schedule inspection picks a date and confirms', (tester) async {
      final scheduler = FakeScheduler();
      final c = await pumpReadiness(tester, scheduler: scheduler, size: const Size(390, 1800));
      await openWorst(tester, c, 'S3');
      await tapVisible(tester, find.byKey(const Key('schedule-inspection')));
      await tester.tap(find.text('OK'));
      await settle(tester, 6);

      expect(scheduler.calls.single.$1, 'S3');
      expect(scheduler.reloads, 1);
      expect(find.textContaining('Inspection scheduled for 7 Nov'), findsOneWidget);
    });

    testWidgets('cancelling the date picker schedules nothing', (tester) async {
      final scheduler = FakeScheduler();
      final c = await pumpReadiness(tester, scheduler: scheduler, size: const Size(390, 1800));
      await openWorst(tester, c, 'S3');
      await tapVisible(tester, find.byKey(const Key('schedule-inspection')));
      await tester.tap(find.text('Cancel'));
      await settle(tester, 6);
      expect(scheduler.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failing save shows an error', (tester) async {
      final scheduler = FakeScheduler(failFor: {'S3'});
      final c = await pumpReadiness(tester, scheduler: scheduler, size: const Size(390, 1800));
      await openWorst(tester, c, 'S3');
      await tapVisible(tester, find.byKey(const Key('schedule-inspection')));
      await tester.tap(find.text('OK'));
      await settle(tester, 6);
      expect(find.text('Could not schedule the inspection. Please try again.'), findsOneWidget);
    });
  });

  group('bulk actions', () {
    Future<void> selectOverdue(WidgetTester tester) async {
      await tapVisible(tester, find.byKey(const Key('select-button')));
      await tapVisible(tester, find.byKey(const Key('select-overdue')));
      expect(find.text('2 selected'), findsOneWidget);
    }

    testWidgets('select all overdue, then schedule one date for all', (tester) async {
      final scheduler = FakeScheduler();
      await pumpReadiness(tester, scheduler: scheduler);
      await selectOverdue(tester);
      await tapVisible(tester, find.byKey(const Key('bulk-schedule')));
      await tester.tap(find.text('OK'));
      await settle(tester, 6);

      expect(scheduler.calls.map((e) => e.$1).toSet(), {'S2', 'S3'});
      expect(scheduler.calls.every((e) => e.$2 == DateTime(2026, 11, 7)), isTrue);
      expect(find.textContaining('Scheduled 2 inspections'), findsOneWidget);
    });

    testWidgets('partial failure lists the units that failed', (tester) async {
      final scheduler = FakeScheduler(failFor: {'S2'});
      await pumpReadiness(tester, scheduler: scheduler);
      await selectOverdue(tester);
      await tapVisible(tester, find.byKey(const Key('bulk-schedule')));
      await tester.tap(find.text('OK'));
      await settle(tester, 6);

      expect(scheduler.calls.map((e) => e.$1), ['S3']);
      expect(find.text('Scheduled 1 of 2 inspections'), findsOneWidget);
      expect(find.textContaining('Generac RG'), findsWidgets);
      expect(find.textContaining('Could not be saved'), findsOneWidget);
    });

    testWidgets('long-press starts selecting', (tester) async {
      final c = await pumpReadiness(tester);
      await tester.longPress(find.byKey(Key('unit-${unitKey(c, 'S3')}')).first, warnIfMissed: false);
      await settle(tester, 2);
      // The cards sit below the fold; scroll to one and long-press it.
      await scrollTo(tester, find.byKey(Key('unit-${unitKey(c, 'S3')}')));
      await tester.longPress(find.byKey(Key('unit-${unitKey(c, 'S3')}')));
      await settle(tester, 2);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('Export selected exports just the selection', (tester) async {
      final exporter = FakeExporter();
      await pumpReadiness(tester, exporter: exporter);
      await selectOverdue(tester);
      await tapVisible(tester, find.byKey(const Key('bulk-export')));
      expect(exporter.csvCalls.single.map((u) => u.serial).toSet(), {'S2', 'S3'});
    });
  });

  group('export', () {
    Future<void> choose(WidgetTester tester, String item) async {
      await tester.tap(find.byKey(const Key('export-menu')));
      await settle(tester, 3);
      await tester.tap(find.text(item));
      await settle(tester, 6);
    }

    testWidgets('CSV and PDF respect the current filters', (tester) async {
      final exporter = FakeExporter();
      await pumpReadiness(tester, exporter: exporter);
      await tester.tap(find.byKey(const Key('export-menu')));
      await settle(tester, 3);
      expect(find.text('Export CSV (12 units)'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await settle(tester, 3);

      await tapVisible(tester, find.byKey(const Key('stat-notReady')));
      await choose(tester, 'Export CSV (2 units)');
      expect(exporter.csvCalls.single, hasLength(2));

      await choose(tester, 'Export PDF report (2 units)');
      final data = exporter.pdfCalls.single;
      expect(data.units, hasLength(2));
      expect(data.filtered, isTrue);
      expect(data.summary.total, 12);
      expect(find.text('Report saved in Documents'), findsOneWidget);
    });

    testWidgets('a CSV failure shows an error snackbar', (tester) async {
      await pumpReadiness(tester, exporter: FakeExporter(csv: StateError('disk full')));
      await choose(tester, 'Export CSV (12 units)');
      expect(find.text('Could not export the CSV. Please try again.'), findsOneWidget);
    });

    testWidgets('a PDF failure shows an error snackbar', (tester) async {
      await pumpReadiness(tester, exporter: FakeExporter(pdf: StateError('no fonts')));
      await choose(tester, 'Export PDF report (12 units)');
      expect(find.text('Could not create the PDF report. Please try again.'), findsOneWidget);
    });

    testWidgets('cancelling the share sheet shows nothing', (tester) async {
      await pumpReadiness(tester, exporter: FakeExporter(csv: false, pdf: false));
      await choose(tester, 'Export CSV (12 units)');
      expect(find.byType(SnackBar), findsNothing);
      await choose(tester, 'Export PDF report (12 units)');
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('thresholds', () {
    testWidgets('admin changes the due soon window with a live preview', (tester) async {
      final store = MemStore();
      final c = await pumpReadiness(tester, store: store);
      await tester.tap(find.byKey(const Key('readiness-settings')));
      await settle(tester, 4);

      expect(find.text('Generator fleet readiness settings'), findsOneWidget);
      expect(find.text('At 30 days, 3 units would be Due soon'), findsOneWidget);
      expect(find.text('At 30 days, 2 units would be Not ready'), findsOneWidget);

      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byKey(const Key('due-soon-plus')));
        await tester.pump();
      }
      expect(find.text('At 60 days, 4 units would be Due soon'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-save')));
      await settle(tester, 6);
      expect(store.config.dueSoonDays, 60);
      expect(c.read(readinessConfigProvider).dueSoonDays, 60);
      expect(find.text('Generator fleet readiness thresholds saved'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('stat-dueSoon')), matching: find.text('4')),
        findsOneWidget,
      );
    });
  });
}
