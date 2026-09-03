import 'package:hive/hive.dart';

import '../models/vehicle_asset_catalog_item_record.dart';
import '../models/vehicle_asset_record.dart';

/// The tool catalog — what a tool *is*.
class VehicleAssetCatalogBox {
  VehicleAssetCatalogBox._();

  static const boxName = 'vehicle_asset_catalog';
  static Box<VehicleAssetCatalogItemRecord>? _box;

  /// The open box. The cached handle is only trusted while it is still open:
  /// HiveService's reset closes every box and reopens new instances, so a
  /// plain non-null cache hands back a dead one.
  static Box<VehicleAssetCatalogItemRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleAssetCatalogItemRecord>(boxName);
    }
    throw StateError('VehicleAssetCatalogBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleAssetCatalogItemRecord>(boxName)
        : await Hive.openBox<VehicleAssetCatalogItemRecord>(boxName);
  }

  static void invalidate() => _box = null;
}

/// The tools actually in a vehicle — one row per physical item.
class VehicleAssetsBox {
  VehicleAssetsBox._();

  static const boxName = 'vehicle_assets';
  static Box<VehicleAssetRecord>? _box;

  static Box<VehicleAssetRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<VehicleAssetRecord>(boxName);
    }
    throw StateError('VehicleAssetsBox.init() must be called first.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<VehicleAssetRecord>(boxName)
        : await Hive.openBox<VehicleAssetRecord>(boxName);
  }

  static void invalidate() => _box = null;
}
