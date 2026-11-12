import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/last_synced_tracker.dart';

void main() {
  test('loads the persisted value and stamps only clean runs', () async {
    DateTime? store = DateTime.utc(2026, 1, 1);
    var clock = DateTime.utc(2026, 2, 2);
    LastSyncedTracker make() => LastSyncedTracker(
          read: () => store,
          write: (v) async => store = v,
          now: () => clock,
        );

    final t = make();
    expect(t.value, isNull);
    expect(t.load(), DateTime.utc(2026, 1, 1));

    await t.recordRun(failed: 2);
    expect(t.value, DateTime.utc(2026, 1, 1));
    expect(store, DateTime.utc(2026, 1, 1));

    await t.recordRun(failed: 0);
    expect(t.value, clock);
    expect(store, clock);

    // A relaunch sees the stamp.
    clock = DateTime.utc(2026, 3, 3);
    expect(make().load(), DateTime.utc(2026, 2, 2));
  });

  test('a failing write does not lose the in-memory stamp', () async {
    final t = LastSyncedTracker(
      read: () => null,
      write: (_) async => throw StateError('disk'),
      now: () => DateTime.utc(2026, 5, 5),
    );
    await t.recordRun(failed: 0);
    expect(t.value, DateTime.utc(2026, 5, 5));
  });
}
