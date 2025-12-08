// lib/core/services/hive/hive_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hive_adapters.dart';
import 'hive_boxes.dart';

/// Top-level Hive lifecycle manager.
///
/// Call [HiveService.init] from your core init routine (e.g. main)
/// so Hive is always ready before any feature uses it.
class HiveService {
  static bool _initialized = false;

  /// Initialize Hive:
  /// - Hive.initFlutter()
  /// - register all adapters via [HiveAdapters.registerAll]
  /// - open core boxes via [HiveBoxes.init]
  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    HiveAdapters.registerAll();
    await HiveBoxes.init();

    _initialized = true;

    if (kDebugMode) {
      debugPrint('[HiveService] Initialized & core boxes opened.');
    }
  }

  /// Helper in case you want to open extra boxes dynamically later.
  static Future<Box<T>> openBox<T>(String name) async {
    if (!_initialized) {
      throw StateError(
        'HiveService used before initialization. '
            'Call HiveService.init() before runApp().',
      );
    }

    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }
}
