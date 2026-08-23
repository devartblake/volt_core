import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';
import '../../../modules/work_orders/infra/datasources/work_orders_box.dart';
import '../../../modules/templates/infra/datasources/form_responses_box.dart';
import '../../../modules/templates/infra/datasources/template_definitions_box.dart';
import '../storage/file_storage_service.dart';
import 'hive_adapters.dart';
import 'hive_boxes.dart';
import 'hive_migrations.dart';

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
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('[HiveService] Already initialized, skipping');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[HiveService] Initializing...');
    }

    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final hiveDir = await FileStorageService.instance.getHiveDirectory();
      await Hive.initFlutter(hiveDir.path);
      if (kDebugMode) {
        debugPrint('[HiveService] Hive directory: ${hiveDir.path}');
      }
    }

    HiveAdapters.registerAll();

    await HiveBoxes.init();
    await MaintenanceBoxes.init();
    await WorkOrdersBox.init();
    await FormResponsesBox.init();
    await TemplateDefinitionsBox.init();

    // Repair local data written by older builds (e.g. records stored under
    // auto-integer keys instead of their string id). Idempotent and non-fatal.
    await HiveMigrations.runAll();

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

  /// Delete ALL Hive data from disk.
  ///
  /// ⚠️ WARNING: This is destructive! All local data will be permanently lost.
  ///
  /// Use cases:
  /// - Development: Clear corrupted data during testing
  /// - Migration: Clean slate for schema changes
  /// - User action: "Clear all app data" feature
  ///
  /// After calling this, you must call [init] again before using Hive.
  ///
  /// Example:
  /// ```dart
  /// if (kDebugMode) {
  ///   await HiveService.deleteAllData();
  ///   await HiveService.init();
  ///   await MaintenanceBoxes.init();
  /// }
  /// ```
  static Future<void> deleteAllData() async {
    if (kDebugMode) {
      debugPrint('[HiveService] ⚠️  Deleting ALL Hive data from disk...');
    }

    // Close all boxes first
    await closeAll();

    // Delete everything
    await Hive.deleteFromDisk();

    // Reset state
    _initialized = false;

    if (kDebugMode) {
      debugPrint('[HiveService] ✅ All Hive data deleted');
      debugPrint('[HiveService] ℹ️  Call init() again to reinitialize');
    }
  }

  /// Close all open Hive boxes.
  ///
  /// This closes:
  /// - Core boxes from HiveBoxes
  /// - Any other boxes opened via openBox()
  ///
  /// Note: This does NOT delete data, just closes the boxes.
  /// Data remains on disk and can be reopened.
  ///
  /// Use cases:
  /// - App shutdown/cleanup
  /// - Before deleting data
  /// - Memory management
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   HiveService.closeAll();
  ///   super.dispose();
  /// }
  /// ```
  static Future<void> closeAll() async {
    if (kDebugMode) {
      debugPrint('[HiveService] Closing all Hive boxes...');
    }

    // Close core boxes via HiveBoxes
    await HiveBoxes.closeAll();

    // Close any other boxes that might be open
    // (This catches boxes opened via openBox() or MaintenanceBoxes)
    await Hive.close();

    // Drop handles cached elsewhere. Without this, MaintenanceBoxes keeps
    // handing out the box it closed above — its own `_initialized` flag says
    // the cached instance is fine — and the maintenance form throws
    // "Box has already been closed" for the rest of the session.
    MaintenanceBoxes.invalidate();
    WorkOrdersBox.invalidate();
    FormResponsesBox.invalidate();
    TemplateDefinitionsBox.invalidate();

    _initialized = false;

    if (kDebugMode) {
      debugPrint('[HiveService] ✅ All boxes closed');
    }
  }

  /// Reset Hive state and optionally delete data.
  ///
  /// This is a convenience method that combines close + optional delete + reinit.
  ///
  /// Parameters:
  /// - [deleteData]: If true, deletes all data from disk (default: false)
  /// - [reinitialize]: If true, calls init() after cleanup (default: true)
  ///
  /// Use cases:
  /// - Development: Quick reset during debugging
  /// - Migration: Clean state for schema changes
  /// - Testing: Reset between test runs
  ///
  /// Example:
  /// ```dart
  /// // Reset with fresh data
  /// await HiveService.reset(deleteData: true);
  ///
  /// // Just close and reopen (keeps data)
  /// await HiveService.reset(deleteData: false);
  /// ```
  static Future<void> reset({
    bool deleteData = false,
    bool reinitialize = true,
  }) async {
    if (kDebugMode) {
      debugPrint('[HiveService] Resetting Hive...');
      debugPrint('  - Delete data: $deleteData');
      debugPrint('  - Reinitialize: $reinitialize');
    }

    // Close all boxes
    await closeAll();

    // Optionally delete data
    if (deleteData) {
      await Hive.deleteFromDisk();
      if (kDebugMode) {
        debugPrint('[HiveService] ✅ Data deleted');
      }
    }

    // Reset state
    _initialized = false;

    // Optionally reinitialize
    if (reinitialize) {
      await init();
      if (kDebugMode) {
        debugPrint('[HiveService] ✅ Reinitialized');
      }
    }

    if (kDebugMode) {
      debugPrint('[HiveService] ✅ Reset complete');
    }
  }

  /// Check if HiveService is initialized.
  ///
  /// Use this to verify Hive is ready before accessing boxes.
  static bool get isInitialized => _initialized;

  /// Get statistics about open boxes.
  ///
  /// Returns a map of box names to entry counts.
  /// Useful for debugging and monitoring.
  static Map<String, int> getBoxStatistics() {
    final stats = <String, int>{};

    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[HiveService] Not initialized, no stats available');
      }
      return stats;
    }

    // Collect stats from all open boxes
    if (Hive.isBoxOpen(HiveBoxes.inspectionsBoxName)) {
      stats[HiveBoxes.inspectionsBoxName] = HiveBoxes.inspections.length;
    }
    if (Hive.isBoxOpen(HiveBoxes.loadTestsBoxName)) {
      stats[HiveBoxes.loadTestsBoxName] = HiveBoxes.loadTests.length;
    }
    if (Hive.isBoxOpen(HiveBoxes.nameplatesBoxName)) {
      stats[HiveBoxes.nameplatesBoxName] = HiveBoxes.nameplates.length;
    }
    if (Hive.isBoxOpen(HiveBoxes.testIntervalsBoxName)) {
      stats[HiveBoxes.testIntervalsBoxName] = HiveBoxes.testIntervals.length;
    }

    // Note: MaintenanceBoxes would need to be checked separately
    // if you want those stats too

    return stats;
  }

  /// Print debug information about Hive state.
  ///
  /// Only works in debug mode.
  static void printDebugInfo() {
    if (!kDebugMode) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('HIVE SERVICE DEBUG INFO');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Initialized: $_initialized');
    debugPrint('');

    if (_initialized) {
      debugPrint('Box Statistics:');
      final stats = getBoxStatistics();
      if (stats.isEmpty) {
        debugPrint('  No boxes open');
      } else {
        stats.forEach((name, count) {
          debugPrint('  $name: $count entries');
        });
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
