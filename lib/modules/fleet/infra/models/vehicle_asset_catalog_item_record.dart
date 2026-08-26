import 'package:hive/hive.dart';

/// Next free typeId after VehicleMaintenanceCheckRecord's 76.
const int kVehicleAssetCatalogItemTypeId = 77;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kVehicleAssetCatalogItemTypeId)
class VehicleAssetCatalogItemRecord {
  const VehicleAssetCatalogItemRecord({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.partNumber,
    this.category = '',
    this.notes = '',
    this.isActive = true,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String? partNumber;
  @HiveField(4)
  final String category;
  @HiveField(5)
  final String notes;
  @HiveField(6)
  final bool isActive;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final DateTime updatedAt;
}

class VehicleAssetCatalogItemRecordAdapter
    extends TypeAdapter<VehicleAssetCatalogItemRecord> {
  @override
  final int typeId = kVehicleAssetCatalogItemTypeId;

  @override
  VehicleAssetCatalogItemRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleAssetCatalogItemRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      name: fields[2] as String,
      partNumber: fields[3] as String?,
      category: fields[4] as String? ?? '',
      notes: fields[5] as String? ?? '',
      isActive: fields[6] as bool? ?? true,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleAssetCatalogItemRecord value) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.name)
      ..writeByte(3)..write(value.partNumber)
      ..writeByte(4)..write(value.category)
      ..writeByte(5)..write(value.notes)
      ..writeByte(6)..write(value.isActive)
      ..writeByte(7)..write(value.createdAt)
      ..writeByte(8)..write(value.updatedAt);
  }
}
