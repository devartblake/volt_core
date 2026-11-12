import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/generic_names.dart';
import '../../infra/inventory_repository.dart';

/// Admin action: blanks part names that are only a slot label ("Air filter",
/// "Battery"), after asking. Saved through the repository so sync and
/// `updatedAt` follow.
Future<void> cleanUpGenericNames(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(inventoryRepositoryProvider);
  final targets = partsWithGenericNames(await repo.parts());
  if (!context.mounted) return;
  if (targets.isEmpty) {
    AppSnackBar.infoOn(messenger, 'No generic descriptions to clean up.');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Clean up generic names'),
      content: Text(
        '${targets.length} part${targets.length == 1 ? '' : 's'} '
        '${targets.length == 1 ? 'has' : 'have'} a description that is only '
        'the type (like "Air filter" or "Battery"). Clear '
        '${targets.length == 1 ? 'it' : 'them'} so you can write a real '
        'description later?',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel')),
        FilledButton(
            key: const Key('confirm_cleanup'),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Clear descriptions')),
      ],
    ),
  );
  if (ok != true) return;
  var done = 0;
  var failed = 0;
  for (final p in targets) {
    try {
      await repo.savePart(p.copyWith(name: ''));
      done++;
    } catch (_) {
      failed++;
    }
  }
  ref.invalidate(catalogPartsProvider);
  ref.invalidate(stockLevelsProvider);
  if (failed == 0) {
    AppSnackBar.successOn(messenger,
        'Cleared $done description${done == 1 ? '' : 's'}');
  } else {
    AppSnackBar.errorOn(
        messenger, 'Cleared $done, $failed could not be saved');
  }
}
