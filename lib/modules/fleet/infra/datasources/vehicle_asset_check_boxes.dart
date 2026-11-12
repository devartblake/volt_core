import 'package:hive/hive.dart';

import '../models/fleet_reference_records.dart';
import '../models/vehicle_asset_check_record.dart';

/// Signed receipts — the header row.
class VehicleAssetChecksBox {
  VehicleAssetChecksBox._();

  static const boxName = 'vehicle_asset_checks';
  static Box<VehicleAssetCheckRecord>? _box;

  /// The open box. The cached handle is only trusted while it is still open:
  /// HiveService's reset closes every box and reopens new instances, so a
  /// plain non-null cache hands back a dead one.
  static Box<VehicleAssetCheckRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleAssetCheckRecord>(boxName);
    }
    throw StateError('VehicleAssetChecksBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleAssetCheckRecord>(boxName)
        : await Hive.openBox<VehicleAssetCheckRecord>(boxName);
  }

  static void invalidate() => _box = null;
}

/// One row per tool per receipt.
class VehicleAssetCheckLinesBox {
  VehicleAssetCheckLinesBox._();

  static const boxName = 'vehicle_asset_check_lines';
  static Box<VehicleAssetCheckLineRecord>? _box;

  static Box<VehicleAssetCheckLineRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleAssetCheckLineRecord>(boxName);
    }
    throw StateError('VehicleAssetCheckLinesBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleAssetCheckLineRecord>(boxName)
        : await Hive.openBox<VehicleAssetCheckLineRecord>(boxName);
  }

  static void invalidate() => _box = null;
}

/// Published disclaimer versions, cached so a device with no signal can still
/// show a driver what they are being asked to accept.
class AssetDisclaimersBox {
  AssetDisclaimersBox._();

  static const boxName = 'fleet_disclaimers';
  static Box<AssetDisclaimerRecord>? _box;

  static Box<AssetDisclaimerRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<AssetDisclaimerRecord>(boxName);
    }
    throw StateError('AssetDisclaimersBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<AssetDisclaimerRecord>(boxName)
        : await Hive.openBox<AssetDisclaimerRecord>(boxName);
  }

  static void invalidate() => _box = null;
}

/// Depots — the yards vehicles live in.
class FleetDepotsBox {
  FleetDepotsBox._();

  static const boxName = 'fleet_depots';
  static Box<FleetDepotRecord>? _box;

  static Box<FleetDepotRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<FleetDepotRecord>(boxName);
    }
    throw StateError('FleetDepotsBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<FleetDepotRecord>(boxName)
        : await Hive.openBox<FleetDepotRecord>(boxName);
  }

  static void invalidate() => _box = null;
}
