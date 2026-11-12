import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../permissions/domain/permission.dart';
import '../../permissions/presenter/permission_providers.dart';
import '../domain/user_role.dart';
import 'controllers/auth_controller.dart';

/// Whether the signed-in user may finish or sign off work (permission
/// `sign_off_work`).
///
/// By default every role except apprentice has it; an admin can allow or deny
/// it for one person. A UI affordance only: it explains the rule and keeps the
/// buttons honest, it does not replace the server's own checks. With no role
/// (not signed in) it is true, because the router has already refused such a
/// session.
final canSignOffProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider.select((a) => a.currentRole));
  if (role == null) return true;
  return ref.watch(hasPermissionProvider(Permission.signOffWork));
});

/// Whether the signed-in user may delete maintenance records, schedule tasks
/// and documents (permission `delete_records`). Inspections have their own
/// rule (`delete_inspections`). True when not signed in, as above.
final canDeleteRecordsProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider.select((a) => a.currentRole));
  if (role == null) return true;
  return ref.watch(hasPermissionProvider(Permission.deleteRecords));
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
