import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/tenant_user_lookup.dart';
import '../controllers/tenant_role_management_controller.dart';

/// Grant a tenant role to somebody who already has an account.
///
/// Two steps, deliberately: find the account, then choose the role. The admin
/// sees who they matched — name, email, and whether that person is already on
/// the team — before anything is granted. A single combined form would let a
/// mistyped address silently become a privilege handed to the wrong person.
///
/// This does not create accounts. The user signs up themselves, which is what
/// provisions the `user_profiles` row this searches.
class AddTenantMemberDialog extends ConsumerStatefulWidget {
  const AddTenantMemberDialog({super.key});

  @override
  ConsumerState<AddTenantMemberDialog> createState() =>
      _AddTenantMemberDialogState();
}

class _AddTenantMemberDialogState extends ConsumerState<AddTenantMemberDialog> {
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();

  TenantUserLookup? _found;
  String? _message;
  UserRole _role = UserRole.tech;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _found = null;
      _message = null;
    });

    final result = await ref
        .read(tenantRoleManagementControllerProvider.notifier)
        .lookupUser(_emailController.text);

    if (!mounted) return;

    switch (result) {
      case TenantUserFound(:final user):
        setState(() {
          _found = user;
          // Pre-select what they already hold, so an admin who opened this to
          // *change* a role does not have to re-pick the current one.
          _role = user.currentRole ?? UserRole.tech;
        });
      case TenantUserNotFound(:final email):
        setState(() {
          _message = 'No account is registered to $email. They need to sign up '
              'first — accounts cannot be created from here.';
        });
      case TenantUserLookupFailed(:final message):
        setState(() => _message = message);
    }
  }

  Future<void> _submit() async {
    final user = _found;
    if (user == null) return;

    final actor = ref.read(authStateProvider).userId;
    if (actor == null || actor.isEmpty) return;

    setState(() => _submitting = true);
    final reason = _reasonController.text.trim();

    final ok = await ref
        .read(tenantRoleManagementControllerProvider.notifier)
        .addMember(
          user: user,
          role: _role,
          assignedByUserId: actor,
          reason: reason.isEmpty ? null : reason,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      // The controller put the reason on the page's error banner, which is
      // behind this dialog. Close so it is actually readable.
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.displayName} is now ${_role.label} in this tenant.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final looking = ref.watch(tenantRoleManagementControllerProvider).isLookingUp;
    final user = _found;

    return AlertDialog(
      title: const Text('Add a team member'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => looking ? null : _search(),
                decoration: InputDecoration(
                  labelText: 'Email address',
                  hintText: 'name@company.com',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: looking ? null : _search,
                  ),
                ),
              ),
              if (looking) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
              if (user != null) ...[
                const SizedBox(height: 16),
                _FoundUserCard(user: user),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role in this tenant',
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _role = value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    helperText: 'Recorded in the role assignment audit trail.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: user == null || _submitting ? null : _submit,
          child: Text(
            user != null && user.isMember && user.currentRole == _role
                ? 'Re-apply role'
                : 'Grant role',
          ),
        ),
      ],
    );
  }
}

class _FoundUserCard extends StatelessWidget {
  const _FoundUserCard({required this.user});

  final TenantUserLookup user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text(_initials(user.displayName))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (user.email.isNotEmpty)
                  Text(user.email, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                // Say plainly what granting will do here. "Add member" on
                // somebody who is already a supervisor is really a role change,
                // and the admin should know that before they confirm.
                Text(
                  user.isMember
                      ? 'Already on this team as ${user.currentRole?.label ?? 'a member'} — '
                          'granting will change their role.'
                      : 'Not on this team yet.',
                  style: theme.textTheme.bodySmall,
                ),
                if (!user.isActiveAccount)
                  Text(
                    'This account is disabled.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
