// lib/modules/maintenance/infra/datasources/hive_boxes_maintenance.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/maintenance_record.dart';

class MaintenanceBoxes {
  static const maintenanceBoxName = 'maintenance_records';

  static Box<MaintenanceRecord>? _maintenance;
  static bool _initialized = false;

  /// Safe getter – throws a clear error if init() wasn't called
  static Box<MaintenanceRecord> get maintenance {
    if (_initialized && _maintenance != null) {
      return _maintenance!;
    }

    // Try to recover if box is already open but _initialized wasn't set
    if (Hive.isBoxOpen(maintenanceBoxName)) {
      _maintenance = Hive.box<MaintenanceRecord>(maintenanceBoxName);
      _initialized = true;
      return _maintenance!;
    }

    throw StateError(
      'MaintenanceBoxes.init() must be called before accessing maintenance box. '
          'Call await MaintenanceBoxes.init() during app startup.',
    );
  }

  /// Call this once during app startup, after Hive.initFlutter
  static Future<void> init() async {
    if (_initialized && _maintenance != null) {
      return;
    }

    // IMPORTANT: make sure the adapter is registered somewhere before this.
    // If you prefer, you can also register it here:
    //
    // if (!Hive.isAdapterRegistered(MaintenanceRecordAdapter().typeId)) {
    //   Hive.registerAdapter(MaintenanceRecordAdapter());
    // }

    if (!Hive.isBoxOpen(maintenanceBoxName)) {
      _maintenance = await Hive.openBox<MaintenanceRecord>(maintenanceBoxName);
    } else {
      _maintenance = Hive.box<MaintenanceRecord>(maintenanceBoxName);
    }

    _initialized = true;
  }

  /// Check if the box is initialized
  static bool get isInitialized =>
      _initialized && _maintenance != null && Hive.isBoxOpen(maintenanceBoxName);
}
