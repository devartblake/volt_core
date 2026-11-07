import 'package:flutter/material.dart';

import '../../core/theme/status_colors.dart';

/// The app's one snackbar presentation.
///
/// Feedback snackbars were built ad hoc: some plain, some a `Row` of icon plus
/// text, with `Colors.green` / `Colors.orange` / `Colors.red` hardcoded inside
/// `const SnackBar(...)` — which is both inconsistent and unreadable in dark
/// mode, since those raw swatches don't adapt.
///
/// ```dart
/// AppSnackBar.success(context, 'Inspection scheduled');
/// AppSnackBar.error(context, 'Could not send email');
/// ```
///
/// Each method also has an `...On` twin that takes a [ScaffoldMessengerState],
/// for code that resolved the messenger before an `await` and must not touch
/// the build context afterwards:
///
/// ```dart
/// final messenger = ScaffoldMessenger.of(context);
/// await save();
/// AppSnackBar.successOn(messenger, 'Saved');
/// ```
class AppSnackBar {
  const AppSnackBar._();

  // -------------------------------------------------- from a BuildContext

  /// Something completed.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      successOn(ScaffoldMessenger.of(context), message,
          duration: duration, action: action, theme: Theme.of(context));

  /// Something failed. Longer by default — the user may need to read it.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) =>
      errorOn(ScaffoldMessenger.of(context), message,
          duration: duration, action: action, theme: Theme.of(context));

  /// Needs attention, but nothing failed.
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) =>
      warningOn(ScaffoldMessenger.of(context), message,
          duration: duration, action: action, theme: Theme.of(context));

  /// Neutral acknowledgement — themed default colours, no status tint.
  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      infoOn(ScaffoldMessenger.of(context), message,
          duration: duration, action: action, theme: Theme.of(context));

  // ------------------------------------------ from a ScaffoldMessengerState
  //
  // These show on [messenger] directly. They must not look the messenger up
  // again from `messenger.context`: that context is the messenger's *own*
  // element, and `ScaffoldMessenger.of` searches ancestors, so it finds
  // nothing and throws. [theme] defaults to the messenger's theme, which is
  // what an app-level messenger sits under.

  static void successOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    ThemeData? theme,
  }) {
    final t = theme ?? Theme.of(messenger.context);
    _show(
      messenger,
      message: message,
      icon: Icons.check_circle_outline,
      background: t.status.success,
      foreground: t.status.onSuccess,
      duration: duration,
      action: action,
    );
  }

  static void errorOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
    ThemeData? theme,
  }) {
    final scheme = (theme ?? Theme.of(messenger.context)).colorScheme;
    _show(
      messenger,
      message: message,
      icon: Icons.error_outline,
      background: scheme.error,
      foreground: scheme.onError,
      duration: duration,
      action: action,
    );
  }

  static void warningOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    ThemeData? theme,
  }) {
    final t = theme ?? Theme.of(messenger.context);
    _show(
      messenger,
      message: message,
      icon: Icons.warning_amber_outlined,
      background: t.status.warning,
      foreground: t.status.onWarning,
      duration: duration,
      action: action,
    );
  }

  static void infoOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    ThemeData? theme,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  static void _show(
    ScaffoldMessengerState messenger, {
    required String message,
    required IconData icon,
    required Color background,
    required Color foreground,
    required Duration duration,
    SnackBarAction? action,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Decorative: the message beside it already says what happened.
            ExcludeSemantics(child: Icon(icon, color: foreground, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
        backgroundColor: background,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
