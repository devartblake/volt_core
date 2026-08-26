import 'package:hive/hive.dart';

/// Next free typeId after VehicleAssetCatalogItemRecord's 77.
const int kVehicleAssetTypeId = 78;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kVehicleAssetTypeId)
class VehicleAssetRecord {
  const VehicleAssetRecord({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.catalogId,
    required this.assignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.serialNumber,
    this.readiness = 'fmc',
    this.isMissing = false,
    this.notes = '',
    this.retiredAt,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String vehicleId;
  @HiveField(3)
  final String catalogId;
  @HiveField(4)
  final String? serialNumber;
  @HiveField(5)
  final String readiness;
  @HiveField(6)
  final bool isMissing;
  @HiveField(7)
  final String notes;
  @HiveField(8)
  final DateTime assignedAt;
  @HiveField(9)
  final DateTime? retiredAt;
  @HiveField(10)
  final DateTime createdAt;
  @HiveField(11)
  final DateTime updatedAt;
}

class VehicleAssetRecordAdapter extends TypeAdapter<VehicleAssetRecord> {
  @override
  final int typeId = kVehicleAssetTypeId;

  @override
  VehicleAssetRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleAssetRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      vehicleId: fields[2] as String,
      catalogId: fields[3] as String,
      serialNumber: fields[4] as String?,
      readiness: fields[5] as String? ?? 'fmc',
      isMissing: fields[6] as bool? ?? false,
      notes: fields[7] as String? ?? '',
      assignedAt: fields[8] as DateTime,
      retiredAt: fields[9] as DateTime?,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleAssetRecord value) {
    writer
      ..writeByte(12)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.vehicleId)
      ..writeByte(3)..write(value.catalogId)
      ..writeByte(4)..write(value.serialNumber)
      ..writeByte(5)..write(value.readiness)
      ..writeByte(6)..write(value.isMissing)
      ..writeByte(7)..write(value.notes)
      ..writeByte(8)..write(value.assignedAt)
      ..writeByte(9)..write(value.retiredAt)
      ..writeByte(10)..write(value.createdAt)
      ..writeByte(11)..write(value.updatedAt);
  }
}
