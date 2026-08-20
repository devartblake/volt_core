import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/core/theme/status_colors.dart';

void main() {
  group('StatusColors theme extension', () {
    test('is registered on both themes', () {
      expect(AppTheme.lightTheme.extension<StatusColors>(), isNotNull);
      expect(AppTheme.darkTheme.extension<StatusColors>(), isNotNull);
    });

    test('light and dark provide different values', () {
      final light = AppTheme.lightTheme.status;
      final dark = AppTheme.darkTheme.status;

      // The whole point of the extension: raw Colors.green did not adapt.
      expect(light.success, isNot(dark.success));
      expect(light.warning, isNot(dark.warning));
    });

    test('the accessor falls back rather than throwing', () {
      // A bare ThemeData with no extension registered still yields colours.
      expect(ThemeData.light().status.success, StatusColors.light.success);
    });

    test('lerp interpolates between palettes', () {
      final mid = StatusColors.light.lerp(StatusColors.dark, 0.5);
      expect(mid.success, isNot(StatusColors.light.success));
      expect(mid.success, isNot(StatusColors.dark.success));
    });

    test('copyWith replaces only what it is given', () {
      const replacement = Color(0xFF123456);
      final updated = StatusColors.light.copyWith(success: replacement);

      expect(updated.success, replacement);
      expect(updated.warning, StatusColors.light.warning);
      expect(updated.info, StatusColors.light.info);
    });

    group('forSiteGrade', () {
      final status = AppTheme.lightTheme.status;
      const fallback = Color(0xFF000000);

      test('maps the grades used by inspections', () {
        expect(status.forSiteGrade('Green', fallback: fallback), status.success);
        expect(status.forSiteGrade('Amber', fallback: fallback), status.warning);
      });

      test('is case- and whitespace-insensitive', () {
        expect(
          status.forSiteGrade('  green ', fallback: fallback),
          status.success,
        );
        expect(status.forSiteGrade('AMBER', fallback: fallback), status.warning);
      });

      test('falls back for unknown or empty grades', () {
        expect(status.forSiteGrade('', fallback: fallback), fallback);
        expect(status.forSiteGrade('purple', fallback: fallback), fallback);
      });

      test('red uses the supplied error colour when given', () {
        const error = Color(0xFFB3261E);
        expect(
          status.forSiteGrade('Red', fallback: fallback, red: error),
          error,
        );
      });
    });
  });

  group('theme wiring', () {
    testWidgets('Theme.of(context).status resolves inside the app theme',
        (tester) async {
      late StatusColors resolved;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            resolved = Theme.of(context).status;
            return const SizedBox();
          },
        ),
      ));

      expect(resolved.success, StatusColors.light.success);
    });
  });
}
