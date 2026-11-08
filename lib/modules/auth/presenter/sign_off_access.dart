import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_role.dart';
import 'controllers/auth_controller.dart';

/// Whether the signed-in user may finish, sign off or delete work.
///
/// Apprentices work like technicians but cannot do these three things; every
/// other role can (the existing per-action rules still apply on top, e.g.
/// inspections may only be deleted by admins and dispatchers). A UI affordance
/// only: it explains the rule and keeps the buttons honest, it does not replace
/// the server's own checks. With no role (not signed in) it is true, because
/// the router has already refused such a session.
final canSignOffProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider.select((a) => a.currentRole));
  return role?.canSignOff ?? true;
});

/// Small inline explanation shown where an apprentice is blocked.
class SignOffRequiredNotice extends StatelessWidget {
  const SignOffRequiredNotice({super.key, this.message = kApprenticeSignOffMessage});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [kApprenticeSignOffMessage] as a snackbar.
void showSignOffBlocked(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(kApprenticeSignOffMessage)));
}
