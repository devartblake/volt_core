import 'package:hive/hive.dart';

/// Next free typeId. 3, 10-13, 40, 72-74 are taken.
const int kVehicleRecordTypeId = 75;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kVehicleRecordTypeId)
class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.tenantId,
    required this.designation,
    required this.createdAt,
    required this.updatedAt,
    this.vin,
    this.licensePlate = '',
    this.make = '',
    this.model = '',
    this.modelYear,
    this.vehicleType = 'van',
    this.odometer = 0,
    this.status = 'active',
    this.assignedToUserId,
    this.notes = '',
    this.lastCheckAt,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String designation;
  @HiveField(3)
  final String? vin;
  @HiveField(4)
  final String licensePlate;
  @HiveField(5)
  final String make;
  @HiveField(6)
  final String model;
  @HiveField(7)
  final int? modelYear;
  @HiveField(8)
  final String vehicleType;
  @HiveField(9)
  final int odometer;
  @HiveField(10)
  final String status;
  @HiveField(11)
  final String? assignedToUserId;
  @HiveField(12)
  final String notes;
  @HiveField(13)
  final DateTime createdAt;
  @HiveField(14)
  final DateTime updatedAt;

  /// Added in phase 2. Nullable, so the generator-free adapter reads it back
  /// as null on rows written by phase 1 without needing a defaultValue.
  @HiveField(15)
  final DateTime? lastCheckAt;
}

class VehicleRecordAdapter extends TypeAdapter<VehicleRecord> {
  @override
  final int typeId = kVehicleRecordTypeId;

  @override
  VehicleRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      designation: fields[2] as String,
      vin: fields[3] as String?,
      licensePlate: fields[4] as String? ?? '',
      make: fields[5] as String? ?? '',
      model: fields[6] as String? ?? '',
      modelYear: fields[7] as int?,
      vehicleType: fields[8] as String? ?? 'van',
      odometer: fields[9] as int? ?? 0,
      status: fields[10] as String? ?? 'active',
      assignedToUserId: fields[11] as String?,
      notes: fields[12] as String? ?? '',
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      lastCheckAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleRecord value) {
    writer
      ..writeByte(16)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.designation)
      ..writeByte(3)..write(value.vin)
      ..writeByte(4)..write(value.licensePlate)
      ..writeByte(5)..write(value.make)
      ..writeByte(6)..write(value.model)
      ..writeByte(7)..write(value.modelYear)
      ..writeByte(8)..write(value.vehicleType)
      ..writeByte(9)..write(value.odometer)
      ..writeByte(10)..write(value.status)
      ..writeByte(11)..write(value.assignedToUserId)
      ..writeByte(12)..write(value.notes)
      ..writeByte(13)..write(value.createdAt)
      ..writeByte(14)..write(value.updatedAt)
      ..writeByte(15)..write(value.lastCheckAt);
  }
}
