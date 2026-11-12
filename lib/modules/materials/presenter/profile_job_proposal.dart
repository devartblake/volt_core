import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../domain/material_item.dart';
import '../domain/profile_change.dart';
import '../infra/materials_repository.dart';
import '../infra/profile_changes_repository.dart';
import 'profile_change_widgets.dart';

/// "Propose to profile" on an inspection or maintenance form, for people who
/// cannot edit the profile: shows what the job's parts would change on the
/// generator's profile, asks why, and sends it for approval.
///
/// Returns true when a request was sent.
Future<bool?> proposeJobListToProfile(
  BuildContext context,
  WidgetRef ref, {
  required MaterialOwner profile,
  required List<MaterialItem> jobItems,
}) async {
  final current = await ref.read(materialsRepositoryProvider).load(profile);
  final proposed = ProfileChanges.proposalFromJob(current, jobItems);
  final changes = ProfileChanges.diffProfiles(current, proposed);
  if (!context.mounted) return null;
  if (changes.isEmpty) {
    AppSnackBar.info(
        context, 'This list already matches the generator\'s profile.');
    return null;
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => _JobProposalSheet(
      profile: profile,
      current: current,
      proposed: proposed,
      changes: changes,
    ),
  );
}

class _JobProposalSheet extends ConsumerStatefulWidget {
  const _JobProposalSheet({
    required this.profile,
    required this.current,
    required this.proposed,
    required this.changes,
  });

  final MaterialOwner profile;
  final List<MaterialItem> current;
  final List<MaterialItem> proposed;
  final List<ProfileItemChange> changes;

  @override
  ConsumerState<_JobProposalSheet> createState() => _JobProposalSheetState();
}

class _JobProposalSheetState extends ConsumerState<_JobProposalSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Say briefly why this should change.');
      return;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final p = widget.profile;
    try {
      await ref.read(profileChangesRepositoryProvider).propose(
            generatorKey: p.key,
            make: p.make,
            model: p.model,
            serial: p.serial,
            current: widget.current,
            proposed: widget.proposed,
            note: _reason.text,
            proposedByName: ref.read(authStateProvider).displayName ?? '',
          );
      ref.invalidate(profileChangeRequestsProvider);
      ref.invalidate(pendingProfileChangeCountProvider);
      AppSnackBar.successOn(messenger,
          'Sent for approval. The profile changes when a supervisor approves.');
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not save the request. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Propose to profile',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Compared with the generator\'s parts profile, this job\'s list '
              'would make these changes. A supervisor reviews them first.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final c in widget.changes) ProfileChangeTile(change: c),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('proposal_reason'),
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Why should this change?',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('send_for_approval'),
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send for approval'),
            ),
          ],
        ),
      ),
    );
  }
}
