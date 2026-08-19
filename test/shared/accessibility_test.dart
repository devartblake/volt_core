import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/empty_state.dart';
import 'package:voltcore/shared/widgets/loading_indicator.dart';
import 'package:voltcore/shared/widgets/section_card.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('component kit accessibility', () {
    testWidgets('EmptyState text is readable and its icon is not announced',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No inspections yet',
        message: 'Inspections you create will appear here.',
      )));

      // Title and message reach the accessibility tree as one merged node.
      expect(
        find.bySemanticsLabel(RegExp('No inspections yet')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Inspections you create will appear here'),
        ),
        findsOneWidget,
      );

      // ...and the decorative icon does not add a stop of its own.
      expect(
        tester
            .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
            .length,
        greaterThan(0),
      );
      handle.dispose();
    });

    testWidgets('EmptyState groups its text into one announcement',
        (tester) async {
      await tester.pumpWidget(_app(const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing here',
      )));

      expect(find.byType(MergeSemantics), findsOneWidget);
      expect(find.bySemanticsLabel('Nothing here'), findsOneWidget);
    });

    testWidgets('LoadingIndicator has a spoken label', (tester) async {
      await tester.pumpWidget(_app(const LoadingIndicator()));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('LoadingIndicator uses its message as the label',
        (tester) async {
      await tester.pumpWidget(_app(const LoadingIndicator(
        message: 'Loading inspection',
      )));
      expect(find.bySemanticsLabel('Loading inspection'), findsWidgets);
    });

    testWidgets('SectionHeader title is exposed as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SectionCard(
        icon: Icons.verified_user_outlined,
        title: 'FDNY / DEP',
        children: [Text('field')],
      )));

      final node = tester.getSemantics(find.text('FDNY / DEP'));
      expect(node.label, 'FDNY / DEP');
      expect(node.hasFlag(SemanticsFlag.isHeader), isTrue);
      handle.dispose();
    });
  });

  group('tap targets', () {
    testWidgets('kit action buttons meet the 48dp minimum', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_app(EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No inspections yet',
        action: FilledButton(
          onPressed: () {},
          child: const Text('New inspection'),
        ),
      )));

      // Material's own guideline, enforced by the framework matcher.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });
}
