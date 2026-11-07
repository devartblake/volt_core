import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'sync_operation.dart';
import 'sync_providers.dart';
import 'sync_queue.dart';

/// Key identifying one record in the outbox, matching [SyncOperation.entityId].
String pendingKey(String table, String recordId) => '$table/$recordId';

/// The `table/id` keys of every queued row operation (insert, upsert, delete),
/// pending or failed. File uploads are not tied to a record and are skipped.
/// Pure.
Set<String> pendingRecordKeys(Iterable<SyncOperation> ops) => {
      for (final op in ops)
        if (op.type == SyncOpType.insert ||
            op.type == SyncOpType.upsert ||
            op.type == SyncOpType.delete)
          op.entityId,
    };

/// Reads the queue snapshot. Overridable in tests; defaults to the sync
/// service's queue. Returns nothing until the queue's box is open (it is
/// opened by `SyncService.init` at startup), so it never opens Hive itself.
final queuedOperationsLoaderProvider =
    Provider<Future<List<SyncOperation>> Function()>((ref) {
  final service = ref.read(syncServiceProvider);
  return () async => Hive.isBoxOpen(SyncQueue.boxName)
      ? service.queuedOperations()
      : const <SyncOperation>[];
});

/// All `table/id` keys with an unsent operation.
///
/// One queue read per sync-status change (counts or state), shared by every
/// badge on screen, instead of a Hive read per row.
final pendingRecordKeysProvider = FutureProvider<Set<String>>((ref) async {
  // Re-run when the outbox changes. SyncService emits after every enqueue,
  // drain progress and completion.
  ref.watch(syncStatusProvider.select(
    (s) => s.value == null
        ? 'none'
        : '${s.value!.pending}/${s.value!.failed}/${s.value!.state.name}'
            '/${s.value!.lastSyncedAt?.millisecondsSinceEpoch}',
  ));
  try {
    final ops = await ref.read(queuedOperationsLoaderProvider)();
    return pendingRecordKeys(ops);
  } catch (_) {
    // A marker is a nicety; never let a queue read failure break a list.
    return const <String>{};
  }
});
