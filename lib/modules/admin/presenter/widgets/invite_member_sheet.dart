import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/connectivity/connectivity_service.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/invite_validator.dart';
import '../../infra/services/invite_service.dart';
import '../controllers/tenant_role_management_controller.dart';

/// Whether the device can reach the network right now. Overridden in tests.
final inviteOnlineCheckProvider = Provider<Future<bool> Function()>(
  (ref) => ConnectivityService.instance.isOnline,
);

/// What the sheet asks the page to do after it closes.
enum InviteSheetOutcome { done, addExisting }

const Map<UserRole, String> _roleHelp = {
  UserRole.tech:
      'Does the field work: inspections, jobs and their own schedule.',
  UserRole.supervisor:
      'Reviews and approves work, and sees every technician and report.',
  UserRole.dispatcher:
      'Plans the schedule and assigns jobs, but does not do field work.',
  UserRole.admin: 'Full access, including inviting people and changing roles.',
};

/// Checks connectivity, then opens the invite sheet.
Future<InviteSheetOutcome?> showInviteMemberSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final online = await ref.read(inviteOnlineCheckProvider)();
  if (!context.mounted) return null;
  if (!online) {
    AppSnackBar.error(context, kInviteOfflineMessage);
    return null;
  }
  return showModalBottomSheet<InviteSheetOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const InviteMemberSheet(),
  );
}

/// Invite someone by email: name, email, role, optional phone.
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key});

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  UserRole _role = UserRole.tech;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    final request = InviteRequest(
      email: InviteValidator.normalizeEmail(_email.text),
      displayName: _name.text.trim(),
      role: _role,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(inviteServiceProvider).invite(request);
      // Refresh in the background; the sheet does not need to wait for it.
      ref.read(tenantRoleManagementControllerProvider.notifier).load();
      if (mounted) navigator.pop(InviteSheetOutcome.done);
      if (result.invited) {
        AppSnackBar.successOn(
          messenger,
          'Invitation sent to ${request.email}',
          theme: theme,
        );
      } else {
        AppSnackBar.successOn(
          messenger,
          '${request.displayName} already had an account and was added to '
          'the team.',
          theme: theme,
        );
      }
    } on InviteFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The invitation could not be sent. Try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Invite someone', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'They get an email with a link to choose a password.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: InviteValidator.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: InviteValidator.email,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _role = value ?? _role),
              ),
              const SizedBox(height: 6),
              Text(_roleHelp[_role]!, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: InviteValidator.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (_busy) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.send),
                label: Text(_busy ? 'Sending...' : 'Send invitation'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context)
                        .pop(InviteSheetOutcome.addExisting),
                child: const Text('Already have an account? Add them instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
