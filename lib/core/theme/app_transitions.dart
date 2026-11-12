import 'package:flutter/material.dart';

/// App-wide route transitions, wired once through
/// `ThemeData.pageTransitionsTheme` so every `GoRoute(builder: ...)` (which
/// go_router wraps in a `MaterialPage`) picks them up with no per-route edits.
///
/// - The first route in the stack (a top-level section reached with
///   `context.go`) cross-fades with a very slight scale: a "fade through".
/// - Routes pushed on top of another (details, forms) fade and slide up a
///   few pixels.
/// - When the platform asks for reduced motion
///   (`MediaQuery.disableAnimations`) no animation is drawn at all.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({
    this.duration = const Duration(milliseconds: 220),
  });

  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    if (route.isFirst) {
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    }

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTransitions {
  const AppTransitions._();

  /// Theme hook for light and dark [ThemeData]. Pass [duration] (for example
  /// `Duration.zero`) to override, e.g. in tests.
  static PageTransitionsTheme theme({Duration? duration}) {
    final builder = duration == null
        ? const AppPageTransitionsBuilder()
        : AppPageTransitionsBuilder(duration: duration);
    return PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: builder,
    });
  }
}
