import 'package:hive/hive.dart';

import '../models/vehicle_maintenance_check_record.dart';

class VehicleMaintenanceChecksBox {
  VehicleMaintenanceChecksBox._();

  static const boxName = 'vehicle_maintenance_checks';
  static Box<VehicleMaintenanceCheckRecord>? _box;

  /// The open box.
  ///
  /// The cached handle is only trusted while it is still open. HiveService's
  /// reset closes every box and reopens new instances, so a plain non-null
  /// cache hands back a dead one and every use throws "Box has already been
  /// closed" for the rest of the session.
  static Box<VehicleMaintenanceCheckRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleMaintenanceCheckRecord>(boxName);
    }
    throw StateError(
      'VehicleMaintenanceChecksBox.init() must be called before use.',
    );
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleMaintenanceCheckRecord>(boxName)
        : await Hive.openBox<VehicleMaintenanceCheckRecord>(boxName);
  }

  /// Drop the cached handle so the next access re-resolves.
  static void invalidate() => _box = null;
}
