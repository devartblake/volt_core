import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/core/theme/brand_palette.dart';
import 'package:voltcore/shared/widgets/widgets.dart';

void main() {
  test('painter colours match the brand palette', () {
    const light = AppLogoPainter(brightness: Brightness.light);
    expect(light.colors.disc, BrandPalette.brandNavy);
    expect(light.colors.ring, BrandPalette.grey300);
    expect(light.colors.core, BrandPalette.white);
    expect(light.colors.bolt, BrandPalette.brandNavy);

    const dark = AppLogoPainter(brightness: Brightness.dark);
    expect(dark.colors.disc, BrandPalette.paleNavy);
    expect(dark.colors.ring, BrandPalette.grey500);
    expect(dark.colors.core, BrandPalette.deepNavy);
    expect(dark.colors.bolt, BrandPalette.white);
  });

  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('${entry.key}: paints at 24..512 px with a semantics label',
        (tester) async {
      for (final size in [24.0, 40.0, 120.0, 512.0]) {
        await tester.pumpWidget(MaterialApp(
          theme: entry.value,
          home: Center(child: AppLogo(size: size)),
        ));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AppLogo)), Size.square(size));
        expect(find.bySemanticsLabel('Volt Core logo'), findsOneWidget);
      }
    });
  }

  testWidgets('follows theme brightness; onBrand forces the pale variant',
      (tester) async {
    Brightness variant() {
      final paint = tester.widget<CustomPaint>(find.descendant(
          of: find.byType(AppLogo), matching: find.byType(CustomPaint)));
      return (paint.painter! as AppLogoPainter).brightness;
    }

    await tester
        .pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: const AppLogo()));
    expect(variant(), Brightness.dark);

    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const AppLogo()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(variant(), Brightness.light);

    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const AppLogo.onBrand()));
    await tester.pump(const Duration(seconds: 1));
    expect(variant(), Brightness.dark);
  });

  testWidgets('decorative logo is hidden from semantics', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme, home: const AppLogo(decorative: true)));
    expect(find.bySemanticsLabel('Volt Core logo'), findsNothing);
  });
}
