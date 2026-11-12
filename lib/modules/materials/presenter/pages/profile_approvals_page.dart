import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/profile_change.dart';
import '../../infra/materials_repository.dart';
import '../../infra/profile_approval_gateway.dart';
import '../../infra/profile_changes_repository.dart';
import '../profile_change_widgets.dart';

/// Parts-profile change requests waiting for a supervisor, dispatcher or
/// admin: who asked, why, and exactly what would change.
class ProfileApprovalsPage extends ConsumerStatefulWidget {
  const ProfileApprovalsPage({super.key});

  @override
  ConsumerState<ProfileApprovalsPage> createState() =>
      _ProfileApprovalsPageState();
}

class _ProfileApprovalsPageState extends ConsumerState<ProfileApprovalsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final n =
            await ref.read(profileChangesRepositoryProvider).refreshFromCloud();
        if (n > 0 && mounted) _refresh();
      } catch (_) {}
    });
  }

  void _refresh() {
    ref.invalidate(profileChangeRequestsProvider);
    ref.invalidate(pendingProfileChangeCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(profileChangeRequestsProvider);

    return AppPage(
      title: 'Profile approvals',
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Requests could not be loaded.',
          action: TextButton(
            onPressed: _refresh,
            child: const Text('Retry'),
          ),
        ),
        data: (all) {
          final pending = [for (final r in all) if (r.isPending) r];
          if (pending.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'Nothing waiting',
              message: 'When a technician proposes a change to a generator\'s '
                  'parts profile, it shows up here for you to approve or '
                  'reject.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final r in pending)
                _RequestCard(
                  key: ValueKey('request_${r.id}'),
                  request: r,
                  onDone: _refresh,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({super.key, required this.request, required this.onDone});

  final ProfileChangeRequest request;
  final VoidCallback onDone;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  Set<String>? _selected;
  bool _busy = false;

  MaterialOwner get _owner {
    final r = widget.request;
    return MaterialOwner.generator(
      key: r.generatorKey,
      make: r.make,
      model: r.model,
      serial: r.serial,
    );
  }

  Future<void> _approve({required bool onlySelected}) async {
    final r = widget.request;
    final messenger = ScaffoldMessenger.of(context);
    final selected = _selected;
    setState(() => _busy = true);
    try {
      final result = await ref.read(profileChangesRepositoryProvider).approve(
            r.id,
            materials: ref.read(materialsRepositoryProvider),
            only: onlySelected ? selected : null,
            includeStale: onlySelected,
          );
      ref.invalidate(materialItemsProvider(_owner));
      if (result.applied.isEmpty && result.alreadyApplied.isEmpty) {
        AppSnackBar.infoOn(
            messenger,
            'Nothing could be applied: the profile has changed since this '
            'was proposed. Tick the changes you still want, or reject it.');
        if (mounted) setState(() => _busy = false);
        return;
      }
      final n = result.applied.length;
      final left = result.skippedStale.length;
      AppSnackBar.successOn(
          messenger,
          [
            n == 0
                ? 'The profile already had these changes.'
                : n == 1
                    ? 'Applied 1 change.'
                    : 'Applied $n changes.',
            if (left > 0)
              left == 1
                  ? '1 was left out because the profile changed.'
                  : '$left were left out because the profile changed.',
          ].join(' '));
      widget.onDone();
    } on ProfileApprovalOfflineException {
      // Approving changes the profile and the request together on the server,
      // so it needs a connection. The request stays pending.
      AppSnackBar.infoOn(messenger, 'Connect to approve');
      if (mounted) setState(() => _busy = false);
    } on ProfileAlreadyDecidedException catch (e) {
      AppSnackBar.infoOn(messenger, 'This request was already ${e.status}.');
      widget.onDone();
    } catch (_) {
      AppSnackBar.errorOn(messenger, 'Could not approve. Try again.');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (text == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(profileChangesRepositoryProvider)
          .reject(widget.request.id, note: text);
      AppSnackBar.infoOn(messenger, 'Request rejected. The profile is unchanged.');
      widget.onDone();
    } catch (_) {
      AppSnackBar.errorOn(messenger, 'Could not reject. Try again.');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.request;
    final current = ref.watch(materialItemsProvider(_owner)).value;

    final states = <String, ChangeState>{
      for (final c in r.changes)
        c.itemId: current == null
            ? ChangeState.ok
            : ProfileChanges.stateOf(current, c),
    };
    // Changes the profile already has need no decision; stale ones are not
    // ticked until the reviewer chooses them.
    final selected = _selected ??
        {
          for (final c in r.changes)
            if (states[c.itemId] == ChangeState.ok) c.itemId,
        };
    final who = r.proposedByName.isNotEmpty ? r.proposedByName : 'A technician';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              r.generatorLabel.isEmpty ? 'Generator' : r.generatorLabel,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$who · ${formatRequestTime(r.createdAt)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Reason: ${r.note}', style: theme.textTheme.bodyMedium),
            ],
            const Divider(height: AppSpacing.xxl),
            for (final c in r.changes)
              ProfileChangeTile(
                change: c,
                state: states[c.itemId] ?? ChangeState.ok,
                selected: selected.contains(c.itemId),
                onSelected: _busy
                    ? null
                    : (v) => setState(() {
                          final next = {...(_selected ?? selected)};
                          v ? next.add(c.itemId) : next.remove(c.itemId);
                          _selected = next;
                        }),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const ValueKey('approve_all'),
                  onPressed: _busy ? null : () => _approve(onlySelected: false),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('approve_selected'),
                  onPressed: _busy || selected.isEmpty
                      ? null
                      : () => _approve(onlySelected: true),
                  icon: const Icon(Icons.checklist_outlined),
                  label: Text('Approve selected (${selected.length})'),
                ),
                TextButton.icon(
                  key: const ValueKey('reject'),
                  onPressed: _busy ? null : _reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for an optional note; pops the note, or null when cancelled. Owns its
/// controller so it is disposed with the dialog, after the exit animation.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject this request?'),
      content: TextField(
        key: const ValueKey('reject_note'),
        controller: _note,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Note for the technician (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
