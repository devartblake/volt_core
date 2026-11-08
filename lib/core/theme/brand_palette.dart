import 'package:flutter/material.dart';

/// The Volt Core brand palette: single source of truth for every brand colour.
///
/// It comes from logo "B. Core Ring" (navy disc, grey ring, white core, navy
/// bolt). Nothing outside this file (and the status colours in
/// status_colors.dart, which are deliberately separate from the brand) should
/// hold a raw hex value. Screens read colours through `Theme.of(context)`;
/// the login screen's fixed palette and the logo painter read from here.
///
/// Documented with contrast ratios in docs/branding.md and enforced by
/// test/shared/contrast_test.dart.
class BrandPalette {
  const BrandPalette._();

  // ---- Core brand colours (the logo) ------------------------------------

  /// Logo disc / bolt on light surfaces; light-theme primary.
  static const Color brandNavy = Color(0xFF103078);

  /// Deep navy: text on navy tints, the dark logo's core, login background.
  static const Color deepNavy = Color(0xFF0A1F4D);

  /// Neutral greys of the logo ring and secondary text.
  static const Color grey700 = Color(0xFF4B5363);
  static const Color grey500 = Color(0xFF8B93A1);
  static const Color grey300 = Color(0xFFC9CED6);

  static const Color white = Color(0xFFFFFFFF);

  // ---- Dark-mode tints ---------------------------------------------------

  /// Disc of the dark logo variant.
  static const Color paleNavy = Color(0xFFE4E9F3);

  /// Dark-theme primary: a light tint of the brand navy.
  static const Color navyTint = Color(0xFFA9BDF2);

  /// Dark-theme primary container: the brand navy lifted for dark surfaces.
  static const Color navyContainerDark = Color(0xFF1B3A8C);

  // ---- Light surfaces ----------------------------------------------------

  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurfaceLow = Color(0xFFF6F7F9);
  static const Color lightSurfaceMid = Color(0xFFEEF0F4);
  static const Color lightSurfaceHigh = Color(0xFFE7EAF0);
  static const Color lightSurfaceHighest = Color(0xFFDFE3EA);
  static const Color lightSurfaceDim = Color(0xFFDADEE6);
  static const Color lightOnSurface = Color(0xFF12182B);
  static const Color lightPrimaryContainer = Color(0xFFDCE3F4);
  static const Color lightOutline = Color(0xFF727C8E);
  static const Color lightOutlineVariant = grey300;

  // ---- Dark surfaces -----------------------------------------------------

  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121A2B);
  static const Color darkSurfaceLow = Color(0xFF161F32);
  static const Color darkSurfaceMid = Color(0xFF1A2438);
  static const Color darkSurfaceHigh = Color(0xFF222D45);
  static const Color darkSurfaceHighest = Color(0xFF28334B);
  static const Color darkOnSurface = Color(0xFFE6EAF2);
  static const Color darkOnSurfaceVariant = Color(0xFFB4BDCE);
  static const Color darkOutline = Color(0xFF7783A0);
  static const Color darkOutlineVariant = Color(0xFF39445A);

  // ---- Accent (kept distinct from the navy for charts / highlights) ------

  static const Color lightTertiary = Color(0xFF006874);
  static const Color lightTertiaryContainer = Color(0xFFCDEFF3);
  static const Color lightOnTertiaryContainer = Color(0xFF00363D);
  static const Color darkTertiary = Color(0xFF5FD3E0);
  static const Color darkTertiaryContainer = Color(0xFF004F58);
  static const Color darkOnTertiaryContainer = Color(0xFFC4F1F6);

  // ---- Error (the status danger colour, not brand) -----------------------

  static const Color lightError = Color(0xFFA51417);
  static const Color darkError = Color(0xFFFFB4AB);

  // ---- Colour schemes ----------------------------------------------------

  /// Light scheme: navy primary on white / cool light greys.
  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: brandNavy,
    brightness: Brightness.light,
  ).copyWith(
    primary: brandNavy,
    onPrimary: white,
    primaryContainer: lightPrimaryContainer,
    onPrimaryContainer: deepNavy,
    primaryFixed: lightPrimaryContainer,
    primaryFixedDim: navyTint,
    onPrimaryFixed: deepNavy,
    onPrimaryFixedVariant: brandNavy,
    secondary: grey700,
    onSecondary: white,
    secondaryContainer: const Color(0xFFD3DCF1),
    onSecondaryContainer: deepNavy,
    tertiary: lightTertiary,
    onTertiary: white,
    tertiaryContainer: lightTertiaryContainer,
    onTertiaryContainer: lightOnTertiaryContainer,
    error: lightError,
    onError: white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    surface: white,
    onSurface: lightOnSurface,
    onSurfaceVariant: grey700,
    surfaceDim: lightSurfaceDim,
    surfaceBright: white,
    surfaceContainerLowest: white,
    surfaceContainerLow: lightSurfaceLow,
    surfaceContainer: lightSurfaceMid,
    surfaceContainerHigh: lightSurfaceHigh,
    surfaceContainerHighest: lightSurfaceHighest,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: lightOnSurface,
    onInverseSurface: darkOnSurface,
    inversePrimary: navyTint,
    surfaceTint: brandNavy,
  );

  /// Dark scheme: light navy tint on deep navy-grey surfaces (not black).
  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: brandNavy,
    brightness: Brightness.dark,
  ).copyWith(
    primary: navyTint,
    onPrimary: deepNavy,
    primaryContainer: navyContainerDark,
    onPrimaryContainer: lightPrimaryContainer,
    primaryFixed: lightPrimaryContainer,
    primaryFixedDim: navyTint,
    onPrimaryFixed: deepNavy,
    onPrimaryFixedVariant: brandNavy,
    secondary: darkOnSurfaceVariant,
    onSecondary: const Color(0xFF1A2438),
    secondaryContainer: const Color(0xFF2A4084),
    onSecondaryContainer: const Color(0xFFDCE3F4),
    tertiary: darkTertiary,
    onTertiary: const Color(0xFF00363D),
    tertiaryContainer: darkTertiaryContainer,
    onTertiaryContainer: darkOnTertiaryContainer,
    error: darkError,
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: darkSurface,
    onSurface: darkOnSurface,
    onSurfaceVariant: darkOnSurfaceVariant,
    surfaceDim: darkBackground,
    surfaceBright: darkSurfaceHighest,
    surfaceContainerLowest: darkBackground,
    surfaceContainerLow: darkSurfaceLow,
    surfaceContainer: darkSurfaceMid,
    surfaceContainerHigh: darkSurfaceHigh,
    surfaceContainerHighest: darkSurfaceHighest,
    outline: darkOutline,
    outlineVariant: darkOutlineVariant,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: darkOnSurface,
    onInverseSurface: lightOnSurface,
    inversePrimary: brandNavy,
    surfaceTint: navyTint,
  );
}
