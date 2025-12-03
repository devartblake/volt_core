import 'package:hive_flutter/hive_flutter.dart';
import '../models/maintenance_record.dart';

class MaintenanceBoxes {
  static const maintenanceBoxName = 'maintenance_records';

  static Box<MaintenanceRecord>? _maintenance;

  /// Safe getter – opens box on first access if not already open
  static Box<MaintenanceRecord> get maintenance {
    if (_maintenance != null) return _maintenance!;

    // Try to get already opened box
    if (Hive.isBoxOpen(maintenanceBoxName)) {
      _maintenance = Hive.box<MaintenanceRecord>(maintenanceBoxName);
      return _maintenance!;
    }

    // If box isn't open, throw a helpful error
    throw StateError(
        'MaintenanceBoxes.init() must be called before accessing maintenance box. '
            'Call await MaintenanceBoxes.init() during app startup.'
    );
  }

  /// Call this once during app startup, after Hive.initFlutter
  static Future<void> init() async {
    if (!Hive.isBoxOpen(maintenanceBoxName)) {
      _maintenance = await Hive.openBox<MaintenanceRecord>(maintenanceBoxName);
    } else {
      _maintenance = Hive.box<MaintenanceRecord>(maintenanceBoxName);
    }
  }

  /// Check if the box is initialized
  static bool get isInitialized =>
      _maintenance != null || Hive.isBoxOpen(maintenanceBoxName);
}