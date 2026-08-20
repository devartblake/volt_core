import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/shared/widgets/app_snack_bar.dart';

/// Pumps a button that fires [show] against the app theme.
Future<void> _pumpTrigger(
  WidgetTester tester,
  void Function(BuildContext context) show, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => show(context),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

SnackBar _shown(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  group('AppSnackBar', () {
    testWidgets('success uses the themed success colour, not raw green',
        (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.success(c, 'Saved'));

      expect(find.text('Saved'), findsOneWidget);
      expect(
        _shown(tester).backgroundColor,
        AppTheme.lightTheme.status.success,
      );
      expect(_shown(tester).backgroundColor, isNot(Colors.green));
    });

    testWidgets('error uses the scheme error colour', (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.error(c, 'Boom'));

      expect(find.text('Boom'), findsOneWidget);
      expect(
        _shown(tester).backgroundColor,
        AppTheme.lightTheme.colorScheme.error,
      );
    });

    testWidgets('warning uses the themed warning colour', (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.warning(c, 'Careful'));

      expect(
        _shown(tester).backgroundColor,
        AppTheme.lightTheme.status.warning,
      );
    });

    testWidgets('colours adapt to the dark theme', (tester) async {
      await _pumpTrigger(
        tester,
        (c) => AppSnackBar.success(c, 'Saved'),
        theme: AppTheme.darkTheme,
      );

      // The whole reason for the helper: raw Colors.green did not adapt.
      expect(_shown(tester).backgroundColor, AppTheme.darkTheme.status.success);
      expect(
        _shown(tester).backgroundColor,
        isNot(AppTheme.lightTheme.status.success),
      );
    });

    testWidgets('info leaves the default themed background', (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.info(c, 'Heads up'));

      expect(find.text('Heads up'), findsOneWidget);
      expect(_shown(tester).backgroundColor, isNull);
    });

    testWidgets('success is brief', (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.success(c, 'ok'));
      expect(_shown(tester).duration, const Duration(seconds: 3));
    });

    testWidgets('error stays up longer, since it has to be read',
        (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.error(c, 'bad'));
      expect(_shown(tester).duration, const Duration(seconds: 5));
    });

    testWidgets('an action is passed through', (tester) async {
      var tapped = false;
      await _pumpTrigger(
        tester,
        (c) => AppSnackBar.error(
          c,
          'Failed',
          action: SnackBarAction(label: 'Retry', onPressed: () => tapped = true),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(tapped, isTrue);
    });

    testWidgets('the leading icon is not announced separately',
        (tester) async {
      await _pumpTrigger(tester, (c) => AppSnackBar.success(c, 'Saved'));

      // The message already says what happened; the icon is decoration.
      // (SnackBar adds an ExcludeSemantics of its own, hence findsWidgets.)
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.ancestor(
            of: find.byIcon(Icons.check_circle_outline),
            matching: find.byType(ExcludeSemantics),
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
