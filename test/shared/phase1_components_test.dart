import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_tokens.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/shared/widgets/widgets.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ??
          ThemeData(extensions: const [StatusColors.light]),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AppBreakpoints', () {
    test('classifies widths', () {
      expect(AppBreakpoints.of(320), WindowSize.compact);
      expect(AppBreakpoints.of(599.9), WindowSize.compact);
      expect(AppBreakpoints.of(600), WindowSize.medium);
      expect(AppBreakpoints.of(899), WindowSize.medium);
      expect(AppBreakpoints.of(900), WindowSize.expanded);
    });

    test('gutter grows with the window', () {
      expect(AppSpacing.gutter(WindowSize.compact),
          lessThan(AppSpacing.gutter(WindowSize.expanded)));
    });
  });

  group('StatusChip', () {
    testWidgets('shows label with an explicit visible colour', (tester) async {
      await tester.pumpWidget(_app(const StatusChip(
        label: 'Active',
        tone: StatusTone.success,
        icon: Icons.check,
      )));

      final text = tester.widget<Text>(find.text('Active'));
      expect(text.style?.color, StatusColors.light.success);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('danger uses the error colour', (tester) async {
      await tester.pumpWidget(
          _app(const StatusChip(label: 'Out', tone: StatusTone.danger)));
      final scheme = Theme.of(tester.element(find.text('Out'))).colorScheme;
      expect(tester.widget<Text>(find.text('Out')).style?.color, scheme.error);
    });

    testWidgets('colored uses the supplied colours', (tester) async {
      await tester.pumpWidget(_app(const StatusChip.colored(
        label: 'Custom',
        foreground: Color(0xFF123456),
      )));
      expect(tester.widget<Text>(find.text('Custom')).style?.color,
          const Color(0xFF123456));
    });
  });

  group('InfoChip', () {
    testWidgets('plain and filled variants render the label', (tester) async {
      await tester.pumpWidget(_app(const Column(children: [
        InfoChip(icon: Icons.place, label: 'Site A'),
        InfoChip(icon: Icons.event, label: 'Nov 3', filled: true),
      ])));
      expect(find.text('Site A'), findsOneWidget);
      expect(find.text('Nov 3'), findsOneWidget);
    });
  });

  group('StatCard', () {
    testWidgets('shows value and label and reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(SizedBox(
        width: 220,
        child: StatCard(
          icon: Icons.assignment,
          label: 'Open jobs',
          value: '12',
          subtitle: '3 overdue',
          onTap: () => taps++,
        ),
      )));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Open jobs'), findsOneWidget);
      expect(find.text('3 overdue'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

      await tester.tap(find.byType(StatCard));
      expect(taps, 1);
    });

    testWidgets('exposes one merged semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SizedBox(
        width: 220,
        child: StatCard(
          icon: Icons.build,
          label: 'Due today',
          value: '4',
          compact: true,
        ),
      )));
      expect(find.bySemanticsLabel('Due today: 4'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Skeleton', () {
    testWidgets('builds and animates without error', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(
        width: 300,
        height: 400,
        child: SkeletonList(count: 3),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Skeleton), findsNWidgets(3));
    });

    testWidgets('stays still with reduced motion', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const Skeleton(width: 100)),
      ));
      // No repeating ticker: this settles instead of timing out.
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsOneWidget);
    });
  });
}
