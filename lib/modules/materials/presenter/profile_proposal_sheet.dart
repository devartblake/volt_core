import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../domain/material_item.dart';
import '../domain/material_list.dart';
import '../domain/profile_change.dart';
import '../infra/materials_repository.dart';
import '../infra/profile_changes_repository.dart';
import 'materials_editor.dart';
import 'profile_change_widgets.dart';

/// An in-memory stand-in for the materials store, so the editor can work on a
/// COPY of a profile: nothing it does reaches the device store or the sync
/// queue, and the real profile is untouched until a reviewer approves.
class DraftMaterialsRepository extends MaterialsRepository {
  DraftMaterialsRepository(List<MaterialItem> initial) : _items = [...initial];

  List<MaterialItem> _items;

  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async => _items;

  @override
  Future<List<MaterialItem>> save(
    MaterialOwner owner,
    List<MaterialItem> items,
  ) async {
    _items = [...items];
    return _items;
  }

  @override
  Future<void> saveDraft(MaterialOwner owner, List<MaterialItem> items) async {
    _items = [...items];
  }

  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async => const [];
}

/// Opens the editor on a copy of the generator's profile so a technician can
/// propose a change. Returns true when a request was sent.
Future<bool?> showProfileProposalSheet(
  BuildContext context, {
  required String make,
  required String model,
  required String serial,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ProfileProposalSheet(make: make, model: model, serial: serial),
    ),
  );
}

class ProfileProposalSheet extends ConsumerStatefulWidget {
  const ProfileProposalSheet({
    super.key,
    required this.make,
    required this.model,
    required this.serial,
  });

  final String make;
  final String model;
  final String serial;

  @override
  ConsumerState<ProfileProposalSheet> createState() =>
      _ProfileProposalSheetState();
}

class _ProfileProposalSheetState extends ConsumerState<ProfileProposalSheet> {
  final _reason = TextEditingController();
  late final String _key = generatorProfileKey(
      make: widget.make, model: widget.model, serial: widget.serial);
  late final MaterialOwner _owner = MaterialOwner.generator(
    key: _key,
    make: widget.make.trim(),
    model: widget.model.trim(),
    serial: widget.serial.trim(),
  );

  DraftMaterialsRepository? _draft;
  List<MaterialItem> _current = const [];
  List<MaterialItem> _proposed = const [];
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final current = await ref.read(materialsRepositoryProvider).load(_owner);
      if (!mounted) return;
      setState(() {
        _current = current;
        _proposed = current;
        _draft = DraftMaterialsRepository(current);
      });
    });
  }

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
    final changes = ProfileChanges.diffProfiles(_current, _proposed);
    if (changes.isEmpty) {
      setState(() => _error = 'Change something first, then send it.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(profileChangesRepositoryProvider).propose(
            generatorKey: _key,
            make: widget.make.trim(),
            model: widget.model.trim(),
            serial: widget.serial.trim(),
            current: _current,
            proposed: _proposed,
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
    final draft = _draft;
    final changeCount = ProfileChanges.diffProfiles(_current, _proposed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Propose a profile change',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Edit this copy. The real profile does not change until '
                      'a supervisor approves.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: draft == null
              ? const LoadingIndicator()
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProviderScope(
                        overrides: [
                          materialsRepositoryProvider.overrideWithValue(draft),
                        ],
                        child: MaterialsEditor(
                          owner: _owner,
                          mode: MaterialsMode.profile,
                          onChanged: (items) => setState(() => _proposed = items),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const ValueKey('proposal_reason'),
                        controller: _reason,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Why should this change?',
                          hintText: 'For example: the filter on site is a '
                              'different part number',
                          errorText: _error,
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        changeCount == 0
                            ? 'No changes yet.'
                            : changeCount == 1
                                ? '1 change to send.'
                                : '$changeCount changes to send.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        key: const ValueKey('send_for_approval'),
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Send for approval'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// On the generator profile sheet: a technician's "Propose a change" button
/// and their own requests ("Waiting for approval", with Withdraw); for
/// reviewers, a "N waiting" chip that opens the approvals page.
class ProfileRequestsPanel extends ConsumerStatefulWidget {
  const ProfileRequestsPanel({
    super.key,
    required this.canEdit,
    required this.make,
    required this.model,
    required this.serial,
  });

  final bool canEdit;
  final String make;
  final String model;
  final String serial;

  @override
  ConsumerState<ProfileRequestsPanel> createState() =>
      _ProfileRequestsPanelState();
}

class _ProfileRequestsPanelState extends ConsumerState<ProfileRequestsPanel> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final n =
            await ref.read(profileChangesRepositoryProvider).refreshFromCloud();
        if (n > 0 && mounted) {
          ref.invalidate(profileChangeRequestsProvider);
          ref.invalidate(pendingProfileChangeCountProvider);
        }
      } catch (_) {}
    });
  }

  Future<void> _withdraw(ProfileChangeRequest r) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileChangesRepositoryProvider).withdraw(r.id);
    ref.invalidate(profileChangeRequestsProvider);
    ref.invalidate(pendingProfileChangeCountProvider);
    AppSnackBar.infoOn(messenger, 'Request withdrawn.');
  }

  void _openApprovals() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(RoutePaths.materialsApprovals);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = generatorProfileKey(
        make: widget.make, model: widget.model, serial: widget.serial);
    if (key.isEmpty) return const SizedBox.shrink();

    final all = (ref.watch(profileChangeRequestsProvider).value ??
            const <ProfileChangeRequest>[])
        .where((r) => r.generatorKey == key)
        .toList();

    if (widget.canEdit) {
      final waiting = all.where((r) => r.isPending).length;
      if (waiting == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            key: const ValueKey('waiting_chip'),
            avatar: const Icon(Icons.rate_review_outlined, size: 18),
            label: Text('$waiting waiting'),
            onPressed: _openApprovals,
          ),
        ),
      );
    }

    final uid = ref.watch(authStateProvider).userId;
    final mine = [for (final r in all) if (r.proposedBy == uid) r];
    final waiting = [for (final r in mine) if (r.isPending) r];
    final decided = [
      for (final r in mine)
        if (r.status == ProfileRequestStatus.approved ||
            r.status == ProfileRequestStatus.rejected)
          r,
    ].take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You can see what this generator takes. If it is wrong, send a '
            'change for a supervisor to approve.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('propose_change'),
              onPressed: () async {
                await showProfileProposalSheet(
                  context,
                  make: widget.make,
                  model: widget.model,
                  serial: widget.serial,
                );
              },
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Propose a change'),
            ),
          ),
          for (final r in waiting)
            _RequestCard(
              key: ValueKey('mine_${r.id}'),
              request: r,
              trailing: TextButton(
                onPressed: () => _withdraw(r),
                child: const Text('Withdraw'),
              ),
            ),
          for (final r in decided) _RequestCard(request: r),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({super.key, required this.request, this.trailing});

  final ProfileChangeRequest request;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final tone = switch (r.status) {
      ProfileRequestStatus.pending => StatusTone.warning,
      ProfileRequestStatus.approved => StatusTone.success,
      ProfileRequestStatus.rejected => StatusTone.danger,
      ProfileRequestStatus.withdrawn => StatusTone.neutral,
    };
    final n = r.changes.length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(label: r.status.label, tone: tone),
                Text(
                  '${n == 1 ? '1 change' : '$n changes'} · '
                  '${formatRequestTime(r.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (r.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(r.note, style: theme.textTheme.bodyMedium),
              ),
            if (r.reviewNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Reviewer: ${r.reviewNote}',
                    style: theme.textTheme.bodySmall),
              ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}
