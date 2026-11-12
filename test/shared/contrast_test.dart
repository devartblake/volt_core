import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/core/theme/brand_palette.dart';
import 'package:voltcore/core/theme/signature_palette.dart';
import 'package:voltcore/core/theme/status_colors.dart';

/// WCAG 2.x contrast audit of the light and dark themes. Pure colour maths on
/// the theme tokens, so it needs no widget pumping.
double _lum(Color c) => c.computeLuminance();

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] (possibly translucent) painted over opaque [bg].
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

const _text = 4.5;
const _ui = 3.0;

void main() {
  final themes = {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme};

  for (final entry in themes.entries) {
    final name = entry.key;
    final theme = entry.value;
    final s = theme.colorScheme;
    final st = theme.status;

    test('$name: WCAG AA contrast of themed pairs', () {
      final failures = <String>[];
      void check(String label, Color fg, Color bg, [double min = _text]) {
        final fgOver = over(fg, bg);
        final r = contrast(fgOver, bg);
        if (r < min) {
          failures.add('$name  $label  ${r.toStringAsFixed(2)} < $min');
        }
      }

      // StatusChip: text on the 12% tint of itself over surface / card.
      final tones = {
        'success': st.success,
        'warning': st.warning,
        'danger': s.error,
        'info': st.info,
        'neutral': s.onSurfaceVariant,
      };
      for (final surface in {
        'surface': s.surface,
        'surfaceContainerHighest': s.surfaceContainerHighest,
      }.entries) {
        tones.forEach((tone, fg) {
          check('StatusChip $tone on ${surface.key}', fg,
              over(fg.withValues(alpha: 0.12), surface.value));
        });
      }

      // Status containers.
      check('success on successContainer', st.success, st.successContainer);
      check('warning on warningContainer', st.warning, st.warningContainer);
      check('info on infoContainer', st.info, st.infoContainer);
      check('onSuccess on success', st.onSuccess, st.success);
      check('onWarning on warning', st.onWarning, st.warning);

      // Choice / filter chips.
      check('chip selected label', s.onSecondaryContainer, s.secondaryContainer);
      check('chip unselected label', s.onSurface, s.surface);

      // Buttons (disabled controls are exempt under WCAG 1.4.3).
      check('FilledButton/Elevated label', s.onPrimary, s.primary);
      check('OutlinedButton label', s.primary, s.surface);
      check('TextButton label', s.primary, s.surface);
      check('OutlinedButton border', s.outline, s.surface, _ui);

      // Snackbars (all AppSnackBar variants).
      check('snackbar success', st.onSuccess, st.success);
      check('snackbar warning', st.onWarning, st.warning);
      check('snackbar error', s.onError, s.error);
      check('snackbar info', s.onInverseSurface, s.inverseSurface);

      // Text fields: fill is surfaceContainerHighest @ 0.4 over surface.
      final fill = over(s.surfaceContainerHighest.withValues(alpha: 0.4), s.surface);
      check('field input', s.onSurface, fill);
      check('field label', s.onSurfaceVariant, fill);
      check('field hint', s.onSurfaceVariant.withValues(alpha: 0.9), fill);
      check('field border', s.outline, s.surface, _ui);

      // List tiles / stat cards / info chips.
      check('ListTile title', s.onSurface, s.surface);
      check('ListTile subtitle', s.onSurfaceVariant, s.surface);
      check('StatCard value', s.onSurface, s.surface);
      check('StatCard label', s.onSurfaceVariant, s.surface);
      check('StatCard accent icon', s.primary,
          over(s.primary.withValues(alpha: 0.12), s.surface), _ui);
      check('StatCard.tile accent value', s.primary, s.surface);
      check('InfoChip filled', s.onSurfaceVariant, s.surfaceContainerHighest);
      check('InfoChip emphasized', s.onSurfaceVariant,
          over(s.primaryContainer.withValues(alpha: 0.5), s.surface));

      // Tabs / section chips.
      check('Tab selected', s.primary, s.surface);
      check('Tab unselected', s.onSurfaceVariant, s.surface);

      // Card outline: must be perceptible (decorative, so 1.5:1 minimum).
      check('card outline vs surface', s.outlineVariant, s.surface, 1.5);

      // ignore: avoid_print
      if (failures.isNotEmpty) failures.forEach(print);
      expect(failures, isEmpty);
    });

    test('$name: brand scheme roles (primary, containers, surfaces)', () {
      final failures = <String>[];
      void check(String label, Color fg, Color bg, [double min = _text]) {
        final r = contrast(over(fg, bg), bg);
        if (r < min) {
          failures.add('$name  $label  ${r.toStringAsFixed(2)} < $min');
        }
      }

      final surfaces = {
        'surface': s.surface,
        'surfaceContainerLowest': s.surfaceContainerLowest,
        'surfaceContainerLow': s.surfaceContainerLow,
        'surfaceContainer': s.surfaceContainer,
        'surfaceContainerHigh': s.surfaceContainerHigh,
        'surfaceContainerHighest': s.surfaceContainerHighest,
        'scaffold': theme.scaffoldBackgroundColor,
      };

      check('onPrimary/primary', s.onPrimary, s.primary);
      check('onPrimaryContainer/primaryContainer', s.onPrimaryContainer,
          s.primaryContainer);
      check('onSecondary/secondary', s.onSecondary, s.secondary);
      check('onSecondaryContainer/secondaryContainer',
          s.onSecondaryContainer, s.secondaryContainer);
      check('onTertiary/tertiary', s.onTertiary, s.tertiary);
      check('onTertiaryContainer/tertiaryContainer', s.onTertiaryContainer,
          s.tertiaryContainer);
      check('onError/error', s.onError, s.error);
      check('onErrorContainer/errorContainer', s.onErrorContainer,
          s.errorContainer);
      check('onInverseSurface/inverseSurface', s.onInverseSurface,
          s.inverseSurface);
      check('inversePrimary on inverseSurface (snackbar action)',
          s.inversePrimary, s.inverseSurface);

      surfaces.forEach((n, bg) {
        check('onSurface on $n', s.onSurface, bg);
        check('onSurfaceVariant on $n', s.onSurfaceVariant, bg);
        check('primary text on $n', s.primary, bg);
        check('tertiary text on $n', s.tertiary, bg);
        check('error text on $n', s.error, bg);
        check('outline (field border) vs $n', s.outline, bg, _ui);
        // Status chips (text on a 12% self-tint) on every surface.
        final statusTones = <String, Color>{
          'success': st.success,
          'warning': st.warning,
          'danger': s.error,
          'info': st.info,
          'neutral': s.onSurfaceVariant,
        };
        statusTones.forEach((tone, fg) => check('StatusChip $tone on $n', fg,
            over(fg.withValues(alpha: 0.12), bg)));
        check('signature outline vs $n', SignaturePalette.outline, bg, _ui);
      });

      // Selected states.
      check('selected chip', s.onSecondaryContainer, s.secondaryContainer);
      check('selected chip shape vs surface', s.secondaryContainer, s.surface,
          1.1);
      check('nav indicator icon', s.onPrimaryContainer, s.primaryContainer);
      check('nav indicator vs surface', s.primaryContainer, s.surface, 1.1);
      check('nav rail selected label', s.primary, s.surface);
      check('nav rail unselected label', s.onSurfaceVariant, s.surface);
      check('tab selected', s.primary, s.surface);
      check('tab unselected', s.onSurfaceVariant, s.surface);

      // App bar, as themed.
      final bar = theme.appBarTheme;
      check('app bar foreground', bar.foregroundColor!, bar.backgroundColor!);

      // Snackbar, as themed.
      final sb = theme.snackBarTheme;
      check('snackbar text', sb.contentTextStyle!.color!, sb.backgroundColor!);
      check('snackbar action', sb.actionTextColor!, sb.backgroundColor!);

      // StatCard.
      check('StatCard value', s.onSurface, s.surface);
      check('StatCard accent (tertiary icon)', s.tertiary,
          over(s.tertiary.withValues(alpha: 0.12), s.surface), _ui);

      check('dialog text', s.onSurface, theme.dialogTheme.backgroundColor!);
      check('outlineVariant vs surface', s.outlineVariant, s.surface, 1.3);

      // ignore: avoid_print
      if (failures.isNotEmpty) failures.forEach(print);
      expect(failures, isEmpty);
    });
  }

  test('schemes are built from the brand palette', () {
    final l = AppTheme.lightTheme.colorScheme;
    final d = AppTheme.darkTheme.colorScheme;
    expect(l.primary, BrandPalette.brandNavy);
    expect(l.onPrimaryContainer, BrandPalette.deepNavy);
    expect(l.secondary, BrandPalette.grey700);
    expect(l.outlineVariant, BrandPalette.grey300);
    expect(d.primary, BrandPalette.navyTint);
    expect(d.onPrimary, BrandPalette.deepNavy);
    expect(d.surface, BrandPalette.darkSurface);
    expect(AppTheme.lightTheme.appBarTheme.backgroundColor,
        BrandPalette.brandNavy);
  });

  test('StatusColors extension is registered in both themes', () {
    expect(AppTheme.lightTheme.extension<StatusColors>(), isNotNull);
    expect(AppTheme.darkTheme.extension<StatusColors>(), isNotNull);
  });
}
