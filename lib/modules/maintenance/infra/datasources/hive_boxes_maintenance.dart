import 'package:hive_flutter/hive_flutter.dart';
import '../models/maintenance_record.dart';

class MaintenanceBoxes {
  static const maintenanceBoxName = 'maintenance_records';

  static Box<MaintenanceRecord>? _maintenance;
  static bool _initialized = false;

  /// Safe getter – throws a clear error if init() wasn't called.
  ///
  /// The cached instance is only trusted while it is still open. HiveService's
  /// reset closes every box and reopens new instances, and this used to keep
  /// handing out the dead one.
  static Box<MaintenanceRecord> get maintenance {
    final cached = _maintenance;
    if (_initialized && cached != null && cached.isOpen) {
      return cached;
    }

    // Re-resolve after a reset, or recover if the box is open but
    // _initialized was never set.
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
    final cached = _maintenance;
    if (_initialized && cached != null && cached.isOpen) {
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

  /// Drop the cached handle so the next access re-resolves.
  ///
  /// Called by HiveService.reset, which would otherwise leave this class
  /// holding a closed box that its own `_initialized` flag says is fine.
  static void invalidate() {
    _maintenance = null;
    _initialized = false;
  }
}
