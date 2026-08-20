import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../modules/inspections/infra/models/nameplate_data.dart';
import 'hive_boxes.dart';

/// One-time local-data repairs run at startup, after boxes are open.
///
/// Each migration must be idempotent: it runs on every launch and has to be a
/// no-op once the data is already in the target shape.
class HiveMigrations {
  const HiveMigrations._();

  /// Run all migrations. Never throws — a failed repair must not stop the app
  /// from starting, since the affected data stays readable either way.
  static Future<void> runAll() async {
    try {
      if (Hive.isBoxOpen(HiveBoxes.nameplatesBoxName)) {
        await _rekeyByEntityId<NameplateData>(
          box: HiveBoxes.nameplates,
          idOf: (item) => item.id,
          label: HiveBoxes.nameplatesBoxName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HiveMigrations] migration failed (non-fatal): $e');
      }
    }
  }

  /// Rewrite entries stored under auto-increment integer keys so they are keyed
  /// by their own string id instead.
  ///
  /// Mixed keying let the same record exist twice — once under an int key from
  /// `box.add()` and once under its id from `box.put(id, …)` — with edits
  /// landing on only one copy. Where both exist the id-keyed entry wins, since
  /// that is what every lookup path reads.
  static Future<void> _rekeyByEntityId<T>({
    required Box<T> box,
    required String? Function(T item) idOf,
    required String label,
  }) async {
    if (box.isEmpty) return;

    final intKeys = box.keys.whereType<int>().toList();
    if (intKeys.isEmpty) return;

    var moved = 0;
    var dropped = 0;

    for (final key in intKeys) {
      final item = box.get(key);
      if (item == null) continue;

      final id = idOf(item);
      if (id == null || id.isEmpty) continue;

      if (box.containsKey(id)) {
        // An id-keyed copy already exists and is the one the app reads.
        await box.delete(key);
        dropped++;
      } else {
        await box.put(id, item);
        await box.delete(key);
        moved++;
      }
    }

    if (kDebugMode && (moved > 0 || dropped > 0)) {
      debugPrint('[HiveMigrations] $label: re-keyed $moved by id, '
          'removed $dropped duplicate(s).');
    }
  }
}
