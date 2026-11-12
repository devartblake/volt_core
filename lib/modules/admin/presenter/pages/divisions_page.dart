import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/division.dart';
import '../../infra/division_repository.dart';

/// Admin: the company's divisions. Add, rename, reorder (drag) and deactivate.
/// Online only; offline it says so instead of showing a stale list.
class DivisionsPage extends ConsumerStatefulWidget {
  const DivisionsPage({super.key});

  @override
  ConsumerState<DivisionsPage> createState() => _DivisionsPageState();
}

class _DivisionsPageState extends ConsumerState<DivisionsPage> {
  /// The list while a reorder is being saved, so the row does not jump back.
  List<Division>? _optimistic;
  bool _busy = false;

  DivisionRepository get _repo => ref.read(divisionRepositoryProvider);

  String _message(Object e) => e is DivisionsOfflineException
      ? kDivisionsOfflineMessage
      : e is DivisionNameTakenException
          ? e.toString()
          : 'Could not save the change. Try again.';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    } finally {
      _optimistic = null;
      ref.invalidate(divisionsProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(List<Division> all) async {
    final name = await _askName(context, all: all);
    if (name == null) return;
    await _run(() async {
      await _repo.add(name);
    });
  }

  Future<void> _rename(Division d, List<Division> all) async {
    final name = await _askName(
      context,
      all: all.where((x) => x.id != d.id),
      initial: d.name,
    );
    if (name == null || name == d.name) return;
    await _run(() => _repo.rename(d.id, name));
  }

  Future<void> _reorder(List<Division> items, int from, int to) async {
    final next = [...items];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _optimistic = next);
    await _run(() => _repo.reorder(next));
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ref.watch(divisionsProvider);

    return AppPage(
      title: 'Divisions',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(divisionsProvider),
        ),
      ],
      fab: divisions.hasValue
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _add(divisions.requireValue),
              icon: const Icon(Icons.add),
              label: const Text('Add division'),
            )
          : null,
      body: divisions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is DivisionsOfflineException
            ? EmptyState.offline(
                title: kDivisionsOfflineMessage,
                message: 'Divisions are read from the cloud and are not '
                    'kept on this device.',
                action: TextButton(
                  onPressed: () => ref.invalidate(divisionsProvider),
                  child: const Text('Retry'),
                ),
              )
            : EmptyState.error(
                message: 'Divisions could not be loaded.',
                action: TextButton(
                  onPressed: () => ref.invalidate(divisionsProvider),
                  child: const Text('Retry'),
                ),
              ),
        data: (loaded) {
          final items = _optimistic ?? loaded;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'No divisions yet',
              message: 'Add the divisions your company works in, then give '
                  'each person one on the Technicians page.',
              action: FilledButton.icon(
                onPressed: _busy ? null : () => _add(items),
                icon: const Icon(Icons.add),
                label: const Text('Add division'),
              ),
            );
          }
          return Column(
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Drag to reorder. Turn a division off to stop offering it; '
                  'people already in it keep it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: items.length,
                  onReorderItem: (from, to) => _reorder(items, from, to),
                  itemBuilder: (context, i) {
                    final d = items[i];
                    return Padding(
                      key: ValueKey(d.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DivisionTile(
                        division: d,
                        busy: _busy,
                        onRename: () => _rename(d, items),
                        onActive: (v) => _run(() => _repo.setActive(d.id, v)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DivisionTile extends StatelessWidget {
  const _DivisionTile({
    required this.division,
    required this.busy,
    required this.onRename,
    required this.onActive,
  });

  final Division division;
  final bool busy;
  final VoidCallback onRename;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    division.name,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    division.isActive ? 'Active' : 'Not offered',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Rename ${division.name}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : onRename,
            ),
            Switch(
              value: division.isActive,
              onChanged: busy ? null : onActive,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a division name. Returns the trimmed name, or null if cancelled.
Future<String?> _askName(
  BuildContext context, {
  required Iterable<Division> all,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'Add division' : 'Rename division'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          validator: (v) => validateDivisionName(v, all),
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
