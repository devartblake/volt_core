import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'sync_operation.dart';

/// Durable, offline outbox for pending [SyncOperation]s.
///
/// Backed by a plain `Box<String>` of JSON — intentionally adapter-free so it
/// needs no Hive code generation and can't collide with the app's model
/// typeIds.
class SyncQueue {
  SyncQueue._();

  static final SyncQueue instance = SyncQueue._();

  static const String boxName = 'sync_queue';

  Box<String>? _box;

  Future<Box<String>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) return existing;

    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
    } else {
      _box = await Hive.openBox<String>(boxName);
    }
    return _box!;
  }

  /// Open the underlying box. Safe to call multiple times.
  Future<void> init() async {
    await _ensureBox();
  }

  /// Add [op], collapsing any existing op with the same [SyncOperation.dedupKey]
  /// so repeated edits to one entity don't pile up. The original createdAt is
  /// preserved and the retry counter resets because the payload is now fresh.
  Future<void> enqueue(SyncOperation op) async {
    final box = await _ensureBox();

    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw == null) continue;
      SyncOperation existing;
      try {
        existing = SyncOperation.fromJson(raw);
      } catch (_) {
        continue;
      }
      if (existing.dedupKey == op.dedupKey) {
        final merged = SyncOperation(
          id: existing.id,
          type: op.type,
          entityId: op.entityId,
          payload: op.payload,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        );
        await box.put(existing.id, merged.toJson());
        return;
      }
    }

    await box.put(op.id, op.toJson());
  }

  /// All queued ops, oldest first.
  Future<List<SyncOperation>> all() async {
    final box = await _ensureBox();
    // Snapshot keys so we can delete unreadable entries without mutating the
    // collection we're iterating.
    final keys = box.keys.toList();
    final list = <SyncOperation>[];
    for (final key in keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        list.add(SyncOperation.fromJson(raw));
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncQueue] Dropping unreadable op $key: $e');
        await box.delete(key);
      }
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Persist mutations (attempts, status, lastError) back to disk.
  Future<void> save(SyncOperation op) async {
    final box = await _ensureBox();
    await box.put(op.id, op.toJson());
  }

  Future<void> remove(String opId) async {
    final box = await _ensureBox();
    await box.delete(opId);
  }

  Future<int> count() async => (await _ensureBox()).length;

  Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }
}
