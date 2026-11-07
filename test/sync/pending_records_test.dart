import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/pending_records.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';
import 'package:voltcore/core/services/sync/sync_providers.dart';
import 'package:voltcore/core/services/sync/sync_service.dart';

SyncOperation _op(
  String id,
  SyncOpType type,
  String entityId, {
  SyncOpStatus status = SyncOpStatus.pending,
}) =>
    SyncOperation(
      id: id,
      type: type,
      entityId: entityId,
      payload: const {},
      status: status,
    );

void main() {
  test('pendingRecordKeys keeps row ops (pending and failed), skips files', () {
    final keys = pendingRecordKeys([
      _op('1', SyncOpType.upsert, 'maintenance_records/a'),
      _op('2', SyncOpType.delete, 'maintenance_jobs/b'),
      _op('3', SyncOpType.insert, 'form_responses/c',
          status: SyncOpStatus.failed),
      _op('4', SyncOpType.fileUpload, 'photos/x.jpg'),
      _op('5', SyncOpType.bytesUpload, 'photos/y.jpg'),
    ]);
    expect(keys, {
      'maintenance_records/a',
      'maintenance_jobs/b',
      'form_responses/c',
    });
    expect(keys.contains(pendingKey('maintenance_records', 'a')), isTrue);
  });

  test('provider reloads the queue when the sync status changes', () async {
    final status = StreamController<SyncStatus>();
    addTearDown(status.close);
    var queue = <SyncOperation>[
      _op('1', SyncOpType.upsert, 'maintenance_records/a'),
    ];
    var reads = 0;

    final container = ProviderContainer(overrides: [
      syncStatusProvider.overrideWith((ref) => status.stream),
      queuedOperationsLoaderProvider.overrideWithValue(() async {
        reads++;
        return List.of(queue);
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(pendingRecordKeysProvider, (_, __) {});

    status.add(const SyncStatus(
        state: SyncState.idle, pending: 1, failed: 0));
    await container.read(pendingRecordKeysProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingRecordKeysProvider).value,
        {'maintenance_records/a'});
    final readsAfterFirst = reads;

    // Upload finished: queue empties and the counts change.
    queue = [];
    status.add(const SyncStatus(
        state: SyncState.idle, pending: 0, failed: 0));
    await Future<void>.delayed(Duration.zero);
    await container.read(pendingRecordKeysProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingRecordKeysProvider).value, isEmpty);
    expect(reads, greaterThan(readsAfterFirst));
  });

  test('a failing queue read yields an empty set, not an error', () async {
    final container = ProviderContainer(overrides: [
      syncStatusProvider.overrideWith((ref) => const Stream<SyncStatus>.empty()),
      queuedOperationsLoaderProvider
          .overrideWithValue(() async => throw StateError('hive')),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(pendingRecordKeysProvider.future), isEmpty);
  });
}
