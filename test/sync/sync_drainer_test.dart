import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/sync_drainer.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';
import 'package:voltcore/core/services/sync/sync_queue.dart';

class _MemoryStore implements SyncQueueStore {
  final Map<String, SyncOperation> ops = {};
  void add(String table, int i, {DateTime? at}) {
    final op = SyncOperation(
      id: '$table-$i',
      type: SyncOpType.upsert,
      entityId: '$table/$i',
      payload: {'table': table, 'row': {'id': '$i'}},
      createdAt: at ?? DateTime(2026, 1, 1).add(Duration(seconds: i)),
    );
    ops[op.id] = op;
  }

  @override
  Future<List<SyncOperation>> all() async {
    final l = ops.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return l;
  }

  @override
  Future<void> save(SyncOperation op) async => ops[op.id] = op;

  @override
  Future<void> remove(String opId) async => ops.remove(opId);
}

void main() {
  test('250 queued items are all dispatched in one run, in order', () async {
    final store = _MemoryStore();
    for (var i = 0; i < 250; i++) {
      store.add('parts_catalog', i);
    }
    final sent = <String>[];
    final d = SyncDrainer(
      store: store,
      gap: Duration.zero,
      dispatch: (op) async => sent.add(op.id),
    );
    final r = await d.run();
    expect(r.sent, 250);
    expect(sent.length, 250);
    expect(sent.first, 'parts_catalog-0');
    expect(sent.last, 'parts_catalog-249');
    expect(store.ops, isEmpty);
  });

  test('items enqueued while draining are picked up (regression: stall at ~100)',
      () async {
    final store = _MemoryStore();
    for (var i = 0; i < 20; i++) {
      store.add('a', i);
    }
    final sent = <String>[];
    late SyncDrainer d;
    d = SyncDrainer(
      store: store,
      gap: Duration.zero,
      dispatch: (op) async {
        sent.add(op.id);
        // An import keeps enqueuing and calling sync() while the drain runs.
        if (op.id == 'a-5') {
          for (var i = 100; i < 163; i++) {
            store.add('b', i);
            d.run(); // returns immediately: a drain is already running
          }
        }
      },
    );
    await d.run();
    expect(sent.length, 20 + 63);
    expect(store.ops, isEmpty);
    expect(d.isRunning, isFalse);
  });

  test('a failing item does not block later items; it is retried later',
      () async {
    final store = _MemoryStore();
    for (var i = 0; i < 5; i++) {
      store.add('t', i);
    }
    var now = DateTime(2026, 6, 1);
    final sent = <String>[];
    var failBad = true;
    final d = SyncDrainer(
      store: store,
      gap: Duration.zero,
      now: () => now,
      dispatch: (op) async {
        if (op.id == 't-1' && failBad) throw StateError('boom');
        sent.add(op.id);
      },
    );
    final r = await d.run();
    expect(r.sent, 4);
    expect(r.failed, 1);
    expect(sent, ['t-0', 't-2', 't-3', 't-4']);
    final bad = store.ops['t-1']!;
    expect(bad.attempts, 1);
    expect(bad.lastError, contains('boom'));
    expect(bad.status, SyncOpStatus.pending);

    // Still in backoff: not retried.
    await d.run();
    expect(store.ops.containsKey('t-1'), isTrue);

    // After backoff and recovery, it goes through.
    failBad = false;
    now = now.add(const Duration(minutes: 10));
    bad.updatedAt = DateTime(2026, 6, 1);
    await d.run();
    expect(store.ops, isEmpty);
  });

  test('item is marked failed after maxAttempts and then skipped', () async {
    final store = _MemoryStore()..add('t', 0);
    var now = DateTime(2026, 6, 1);
    var calls = 0;
    final d = SyncDrainer(
      store: store,
      gap: Duration.zero,
      maxAttempts: 3,
      now: () => now,
      dispatch: (op) async {
        calls++;
        throw StateError('nope');
      },
    );
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(hours: 1));
      await d.run();
    }
    expect(calls, 3);
    expect(store.ops['t-0']!.status, SyncOpStatus.failed);
  });
}
