import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';

void main() {
  Future<void> run(WidgetTester tester, {required bool reduced}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('detail')))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('push animates mid-transition by default', (tester) async {
    await run(tester, reduced: false);
    final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.text('detail'), matching: find.byType(FadeTransition)));
    expect(fades.any((f) => f.opacity.value > 0 && f.opacity.value < 1), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('reduced motion draws no fade or slide', (tester) async {
    await run(tester, reduced: true);
    final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.text('detail'), matching: find.byType(FadeTransition)));
    expect(fades.every((f) => f.opacity.value == 1), isTrue);
    expect(
        find.ancestor(of: find.text('detail'), matching: find.byType(SlideTransition)),
        findsNothing);
  });
}
