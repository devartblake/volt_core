import 'package:flutter/widgets.dart';

/// Spacing scale (logical pixels). Use these instead of literal paddings so
/// density can be tuned in one place.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  /// Horizontal page gutter by window size.
  static double gutter(WindowSize size) => switch (size) {
        WindowSize.compact => lg,
        WindowSize.medium => xxl,
        WindowSize.expanded => huge,
      };
}

/// Corner radii shared by cards, chips, sheets and fields.
class AppRadius {
  const AppRadius._();

  static const double chip = 8;
  static const double field = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static BorderRadius get chipAll => BorderRadius.circular(chip);
  static BorderRadius get fieldAll => BorderRadius.circular(field);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Width classes, following Material window size classes.
enum WindowSize { compact, medium, expanded }

/// Breakpoints and a helper to classify a width.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double medium = 600;
  static const double expanded = 900;

  static WindowSize of(double width) {
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  static WindowSize ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}

/// Type sizes for the few places that cannot use a TextTheme role (dense
/// badges). Prefer `Theme.of(context).textTheme` everywhere else.
class AppFontSize {
  const AppFontSize._();

  static const double caption = 12;
  static const double body = 14;
  static const double title = 16;
  static const double headline = 20;
}
