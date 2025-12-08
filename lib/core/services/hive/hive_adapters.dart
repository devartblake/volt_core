import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

// 🔁 Adjust these imports to match your actual model paths & names.
// These are based on the hive_boxes.dart you shared earlier.
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';

/// Central place to register **all** Hive adapters used by the app.
///
/// Called once from [HiveService.init()].
class HiveAdapters {
  static bool _registered = false;

  /// Register all adapters used in the app.
  ///
  /// Safe to call multiple times — subsequent calls will be ignored.
  static void registerAll() {
    if (_registered) return;

    _safeRegister<Inspection>(InspectionAdapter());
    _safeRegister<NameplateData>(NameplateDataAdapter());
    _safeRegister<LoadTestRecord>(LoadTestRecordAdapter());
    _safeRegister<TestIntervalRecord>(TestIntervalRecordAdapter());

    _registered = true;

    if (kDebugMode) {
      debugPrint('[HiveAdapters] All adapters registered.');
    }
  }

  /// Wraps [Hive.registerAdapter] and ignores "already registered" errors
  /// so you can safely call [registerAll] multiple times (e.g. in hot reload).
  static void _safeRegister<T>(TypeAdapter<T> adapter) {
    try {
      Hive.registerAdapter<T>(adapter);
    } on HiveError catch (e) {
      // Typical error when the same adapter is registered twice.
      if (kDebugMode) {
        debugPrint('[HiveAdapters] Adapter for $T not registered: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HiveAdapters] Unexpected error registering $T: $e');
      }
    }
  }
}