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
class AppSnackBar {
  const AppSnackBar._();

  /// Something completed.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final status = Theme.of(context).status;
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      background: status.success,
      foreground: status.onSuccess,
      duration: duration,
      action: action,
    );
  }

  /// Something failed. Longer by default — the user may need to read it.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      background: scheme.error,
      foreground: scheme.onError,
      duration: duration,
      action: action,
    );
  }

  /// Needs attention, but nothing failed.
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final status = Theme.of(context).status;
    _show(
      context,
      message: message,
      icon: Icons.warning_amber_outlined,
      background: status.warning,
      foreground: status.onWarning,
      duration: duration,
      action: action,
    );
  }

  /// Neutral acknowledgement — themed default colours, no status tint.
  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
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
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
    required Color foreground,
    required Duration duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
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
