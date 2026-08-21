import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/shared/widgets/form_fields/status_switch_tile.dart';

Widget _host({
  required bool value,
  required ValueChanged<bool> onChanged,
  StatusTileAccent accent = StatusTileAccent.primary,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(
      body: StatusSwitchTile(
        label: 'Records kept for 5 years',
        icon: Icons.history,
        value: value,
        accent: accent,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  group('StatusSwitchTile', () {
    testWidgets('renders and toggles', (tester) async {
      bool? emitted;
      await tester.pumpWidget(_host(value: false, onChanged: (v) => emitted = v));

      expect(find.text('Records kept for 5 years'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(emitted, isTrue);
    });

    testWidgets('tapping does not trip the ListTile ink assertion',
        (tester) async {
      // The regression guard. Wrapping a SwitchListTile in a DecoratedBox that
      // paints a background makes Flutter assert "ListTile background color or
      // ink splashes may be invisible", because the tile's ink goes to the
      // nearest Material *above* the decoration. Four sections shipped that
      // shape and spammed the log on every rebuild.
      await tester.pumpWidget(_host(value: false, onChanged: (_) {}));

      // Press without releasing: this is what starts the ink splash, which is
      // the code path the assertion lives on.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwitchListTile)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the fill and border sit on a Material, not a DecoratedBox',
        (tester) async {
      // Stated structurally so the fix can't be undone by "simplifying" the
      // Material back into a Container.
      await tester.pumpWidget(_host(value: true, onChanged: (_) {}));

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(SwitchListTile),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(material.color, isNotNull);
      expect(material.shape, isA<RoundedRectangleBorder>());
      expect(
        (material.shape as RoundedRectangleBorder).side.color,
        isNot(Colors.transparent),
      );
    });

    testWidgets('the error accent uses the scheme error role', (tester) async {
      final theme = AppTheme.lightTheme;
      await tester.pumpWidget(_host(
        value: true,
        onChanged: (_) {},
        accent: StatusTileAccent.error,
        theme: theme,
      ));

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(SwitchListTile),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(
        material.color,
        theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      );
    });

    testWidgets('off state is neutral rather than accented', (tester) async {
      final theme = AppTheme.lightTheme;
      await tester.pumpWidget(_host(value: false, onChanged: (_) {}, theme: theme));

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(SwitchListTile),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(
        material.color,
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      );
    });
  });
}
