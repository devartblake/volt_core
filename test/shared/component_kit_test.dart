import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/empty_state.dart';
import 'package:voltcore/shared/widgets/loading_indicator.dart';
import 'package:voltcore/shared/widgets/section_card.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('EmptyState', () {
    testWidgets('shows icon, title, message and action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No inspections yet',
        message: 'Inspections you create will appear here.',
        action: FilledButton(
          onPressed: () => tapped = true,
          child: const Text('New inspection'),
        ),
      )));

      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      expect(find.text('No inspections yet'), findsOneWidget);
      expect(find.text('Inspections you create will appear here.'),
          findsOneWidget);

      await tester.tap(find.text('New inspection'));
      expect(tapped, isTrue);
    });

    testWidgets('message and action are optional', (tester) async {
      await tester.pumpWidget(_app(const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing here',
      )));

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('error variant uses the error colour', (tester) async {
      await tester.pumpWidget(_app(const EmptyState.error(
        message: 'Could not load records.',
      )));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Could not load records.'), findsOneWidget);

      final context = tester.element(find.byType(EmptyState));
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(
        icon.color?.value,
        Theme.of(context).colorScheme.error.withValues(alpha: 0.55).value,
      );
    });

    testWidgets('offline variant explains local-first behaviour',
        (tester) async {
      await tester.pumpWidget(_app(const EmptyState.offline()));

      expect(find.text('You are offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  group('LoadingIndicator', () {
    testWidgets('centres a spinner by default', (tester) async {
      await tester.pumpWidget(_app(const LoadingIndicator()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('shows an optional message', (tester) async {
      await tester.pumpWidget(_app(const LoadingIndicator(
        message: 'Loading inspection…',
      )));

      expect(find.text('Loading inspection…'), findsOneWidget);
    });

    testWidgets('inline variant is small and uncentred', (tester) async {
      await tester.pumpWidget(_app(const LoadingIndicator.inline()));

      final box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.width, 16);
    });
  });

  group('SectionCard', () {
    testWidgets('renders title, subtitle, icon and children', (tester) async {
      await tester.pumpWidget(_app(const SectionCard(
        icon: Icons.verified_user_outlined,
        title: 'FDNY / DEP',
        subtitle: 'Permits and registrations',
        children: [Text('field')],
      )));

      expect(find.text('FDNY / DEP'), findsOneWidget);
      expect(find.text('Permits and registrations'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      expect(find.text('field'), findsOneWidget);
    });

    testWidgets('header works without an icon', (tester) async {
      await tester.pumpWidget(_app(const SectionHeader(title: 'Totals')));
      expect(find.text('Totals'), findsOneWidget);
    });
  });
}
