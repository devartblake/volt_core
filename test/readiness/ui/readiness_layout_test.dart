import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/presenter/widgets/readiness_unit_card.dart';

import 'readiness_ui_harness.dart';

const _sizes = <String, Size>{
  'phone 360x800': Size(360, 800),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

void main() {
  captureOverflows();

  testWidgets('a 300-unit fleet builds only the cards on screen', (tester) async {
    await pumpReadiness(tester, inputs: manyInputs(300), size: const Size(390, 800));
    // Scroll well past the overview so cards are in view.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, 2);
    }
    final built = find.byType(ReadinessUnitCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60), reason: '$built cards built for 300 units');
    expect(find.text('300 units'), findsNothing); // header scrolled away
  });

  for (final dark in [false, true]) {
    for (final e in _sizes.entries) {
      testWidgets('no overflow at 1.3x text: ${e.key}, ${dark ? 'dark' : 'light'}',
          (tester) async {
        final c = await pumpReadiness(
          tester,
          size: e.value,
          textScale: 1.3,
          brightness: dark ? Brightness.dark : Brightness.light,
        );

        // Scroll the whole list so every kind of row is built.
        for (var i = 0; i < 8; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
          await settle(tester, 2);
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 6000));
        await settle(tester, 2);

        // The filter sheet (phone/portrait tablet) and a unit's detail.
        final filters = find.byKey(const Key('filters-button'));
        if (filters.evaluate().isNotEmpty) {
          await tester.ensureVisible(filters);
          await tester.tap(filters);
          await settle(tester, 4);
          await tester.tap(find.text('Done'));
          await settle(tester, 4);
        }
        final worst = find.byKey(Key('worst-${unitKey(c, 'S3')}'));
        await scrollTo(tester, worst);
        await tester.tap(worst);
        await settle(tester, 6);
        expect(find.text('Why needs attention'), findsOneWidget);

        expect(overflows, isEmpty, reason: overflows.map((d) => d.exceptionAsString()).join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final e in _sizes.entries) {
    testWidgets('selection bar and settings sheet fit at 1.3x: ${e.key}', (tester) async {
      await pumpReadiness(tester, size: e.value, textScale: 1.3);
      await tester.tap(find.byKey(const Key('select-button')));
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('select-overdue')));
      await settle(tester, 2);
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('select-button')));
      await settle(tester, 2);

      await tester.tap(find.byKey(const Key('readiness-settings')));
      await settle(tester, 4);
      expect(find.text('Readiness settings'), findsOneWidget);
      expect(overflows, isEmpty, reason: overflows.map((d) => d.exceptionAsString()).join(' | '));
    });
  }
}
