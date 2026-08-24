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
  /// WARNING: This is destructive! All local data will be permanently lost.
  ///
  /// Use cases:
  /// - Development: Clear corrupted data during testing
  /// - Migration: Clean slate for schema changes
  /// - User action: "Clear all app data" feature
  ///
  /// After calling this, you must call [init] again before using Hive.
  static Future<void> deleteAllData() async {
    if (kDebugMode) {
      debugPrint('[HiveService] Deleting ALL Hive data from disk...');
    }

    await closeAll();
    await Hive.deleteFromDisk();
    _initialized = false;

    if (kDebugMode) {
      debugPrint('[HiveService] All Hive data deleted');
      debugPrint('[HiveService] Call init() again to reinitialize');
    }
  }

  /// Close all open Hive boxes without deleting their contents.
  static Future<void> closeAll() async {
    if (kDebugMode) {
      debugPrint('[HiveService] Closing all Hive boxes...');
    }

    await HiveBoxes.closeAll();
    await Hive.close();

    // Drop cached handles owned by feature-level box wrappers. This is required
    // after Hive.close() because those wrappers otherwise retain closed Box
    // instances and fail on the next read after a reset/reinitialize cycle.
    MaintenanceBoxes.invalidate();
    WorkOrdersBox.invalidate();
    TemplateDefinitionsBox.invalidate();

    _initialized = false;

    if (kDebugMode) {
      debugPrint('[HiveService] All boxes closed');
    }
  }

  /// Reset Hive state and optionally delete data.
  static Future<void> reset({
    bool deleteData = false,
    bool reinitialize = true,
  }) async {
    if (kDebugMode) {
      debugPrint('[HiveService] Resetting Hive...');
      debugPrint('  - Delete data: $deleteData');
      debugPrint('  - Reinitialize: $reinitialize');
    }

    await closeAll();

    if (deleteData) {
      await Hive.deleteFromDisk();
      if (kDebugMode) {
        debugPrint('[HiveService] Data deleted');
      }
    }

    _initialized = false;

    if (reinitialize) {
      await init();
      if (kDebugMode) {
        debugPrint('[HiveService] Reinitialized');
      }
    }

    if (kDebugMode) {
      debugPrint('[HiveService] Reset complete');
    }
  }

  /// Check if HiveService is initialized.
  static bool get isInitialized => _initialized;

  /// Get statistics about open boxes.
  static Map<String, int> getBoxStatistics() {
    final stats = <String, int>{};

    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[HiveService] Not initialized, no stats available');
      }
      return stats;
    }

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
    if (Hive.isBoxOpen(TemplateDefinitionsBox.boxName)) {
      stats[TemplateDefinitionsBox.boxName] = TemplateDefinitionsBox.box.length;
    }

    return stats;
  }

  /// Print debug information about Hive state.
  static void printDebugInfo() {
    if (!kDebugMode) return;

    debugPrint('----------------------------------------');
    debugPrint('HIVE SERVICE DEBUG INFO');
    debugPrint('----------------------------------------');
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

    debugPrint('----------------------------------------');
  }
}
