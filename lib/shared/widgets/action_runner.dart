import 'package:flutter/material.dart';

import 'app_snack_bar.dart';

/// Runs a user-triggered share / export / print / email [action] with the
/// feedback every such action needs.
///
/// * [action] returns `true` when it completed and `false` when the user
///   cancelled (file picker closed, share sheet dismissed) or there was
///   nothing to do. `false` is NOT an error: no snackbar is shown.
/// * Anything thrown is logged with `debugPrint` and shown as a plain-language
///   error snackbar (`Could not <label>. Please try again.`); the raw
///   exception text is never shown and nothing escapes.
/// * [busyMessage], when given, is shown as a snackbar while the action runs
///   (for work that can take more than a moment: PDF generation, email, save).
/// * [successMessage] is shown on completion; give it where the user cannot
///   otherwise see the result (saved / emailed / exported).
///
/// The [ScaffoldMessenger] is resolved before the first await, so the caller
/// may be disposed while the action runs. Returns whether the action completed.
Future<bool> runUserAction(
  BuildContext context, {
  required String label,
  required Future<bool> Function() action,
  String? successMessage,
  String? busyMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (busyMessage != null) {
    messenger.hideCurrentSnackBar();
    AppSnackBar.infoOn(messenger, busyMessage,
        duration: const Duration(seconds: 30));
  }
  try {
    final done = await action();
    if (busyMessage != null && messenger.mounted) {
      messenger.hideCurrentSnackBar();
    }
    if (done && successMessage != null && messenger.mounted) {
      AppSnackBar.successOn(messenger, successMessage);
    }
    return done;
  } catch (e, st) {
    debugPrint('[runUserAction] could not $label: $e\n$st');
    if (messenger.mounted) {
      messenger.hideCurrentSnackBar();
      AppSnackBar.errorOn(messenger, 'Could not $label. Please try again.');
    }
    return false;
  }
}
