import 'dart:async';

import 'package:flutter/foundation.dart';

import 'file_backup_service.dart';
import 'sync_operation.dart';
import 'sync_queue.dart';

/// Result of one pass over the queue.
@immutable
class DrainPassResult {
  const DrainPassResult({this.sent = 0, this.failed = 0, this.skipped = 0});

  final int sent;
  final int failed;
  final int skipped;
}

/// Drains a [SyncQueueStore] by handing each operation to [dispatch].
///
/// Separated from `SyncService` so the loop can be tested without Supabase or
/// Hive.
///
/// Why this loops: a pass works from a snapshot of the queue taken when it
/// starts. Anything enqueued while the pass is running (a bulk import enqueues
/// hundreds of rows while the first rows are already uploading) is not in that
/// snapshot, and the `run()` calls those enqueues trigger used to be dropped
/// because a drain was already in progress. Nothing re-armed afterwards, so the
/// queue sat there until the next relaunch. A call that arrives mid-drain now
/// schedules another pass.
class SyncDrainer {
  SyncDrainer({
    required this.store,
    required this.dispatch,
    this.maxAttempts = 8,
    this.gap = const Duration(milliseconds: 40),
    DateTime Function()? now,
    this.onProgress,
    this.onError,
  }) : _now = now ?? DateTime.now;

  final SyncQueueStore store;
  final Future<void> Function(SyncOperation op) dispatch;
  final int maxAttempts;

  /// Pause between items so a large queue does not hammer the server.
  final Duration gap;
  final DateTime Function() _now;

  /// Called every few items so the UI count moves during a long drain.
  final FutureOr<void> Function()? onProgress;

  /// Debug hook for failed items.
  final void Function(Object error, SyncOperation op)? onError;

  bool _running = false;
  bool _again = false;

  bool get isRunning => _running;

  /// Drain until no request arrived during the last pass. Returns the combined
  /// result. If a drain is already running, flags another pass and returns an
  /// empty result immediately.
  Future<DrainPassResult> run({Future<void> Function(List<SyncOperation>)? prepare}) async {
    if (_running) {
      _again = true;
      return const DrainPassResult();
    }
    _running = true;
    var sent = 0, failed = 0, skipped = 0;
    try {
      do {
        _again = false;
        final ops = await store.all();
        if (prepare != null) await prepare(ops);
        final r = await _pass(ops);
        sent += r.sent;
        failed += r.failed;
        skipped += r.skipped;
      } while (_again);
    } finally {
      _running = false;
    }
    return DrainPassResult(sent: sent, failed: failed, skipped: skipped);
  }

  Future<DrainPassResult> _pass(List<SyncOperation> ops) async {
    var sent = 0, failed = 0, skipped = 0, n = 0;
    for (final op in ops) {
      if (op.status == SyncOpStatus.failed && op.attempts >= maxAttempts) {
        skipped++;
        continue;
      }
      if (op.attempts > 0 && !_backoffElapsed(op)) {
        skipped++;
        continue;
      }

      try {
        await dispatch(op);
        await store.remove(op.id);
        sent++;
      } on FileBackupSkip catch (e) {
        if (kDebugMode) debugPrint('[Sync] Dropping op ${op.id}: $e');
        await store.remove(op.id);
      } catch (e) {
        failed++;
        op.attempts += 1;
        op.updatedAt = _now();
        op.lastError = e.toString();
        if (op.attempts >= maxAttempts) op.status = SyncOpStatus.failed;
        await store.save(op);
        if (kDebugMode) {
          debugPrint('[Sync] ${op.type.name} failed (attempt ${op.attempts}): $e');
          onError?.call(e, op);
        }
      }

      if (++n % 10 == 0) await onProgress?.call();
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    return DrainPassResult(sent: sent, failed: failed, skipped: skipped);
  }

  bool _backoffElapsed(SyncOperation op) {
    final exp = op.attempts.clamp(0, 8);
    final delaySeconds = (1 << exp).clamp(1, 300);
    return _now().isAfter(op.updatedAt.add(Duration(seconds: delaySeconds)));
  }
}
