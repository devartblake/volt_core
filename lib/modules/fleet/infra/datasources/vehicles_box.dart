import 'package:hive/hive.dart';

import '../models/vehicle_record.dart';

class VehiclesBox {
  VehiclesBox._();

  static const boxName = 'fleet_vehicles';
  static Box<VehicleRecord>? _box;

  /// The open box.
  ///
  /// The cached handle is only trusted while it is still open. HiveService's
  /// reset closes every box and reopens new instances, so a plain non-null
  /// cache hands back a dead one and every use throws "Box has already been
  /// closed" for the rest of the session.
  static Box<VehicleRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleRecord>(boxName);
    }
    throw StateError('VehiclesBox.init() must be called before use.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleRecord>(boxName)
        : await Hive.openBox<VehicleRecord>(boxName);
  }

  /// Drop the cached handle so the next access re-resolves.
  static void invalidate() => _box = null;
}
