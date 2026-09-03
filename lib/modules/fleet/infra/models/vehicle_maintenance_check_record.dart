import 'package:hive/hive.dart';

/// Next free typeId after VehicleRecord's 75.
const int kVehicleMaintenanceCheckTypeId = 76;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kVehicleMaintenanceCheckTypeId)
class VehicleMaintenanceCheckRecord {
  const VehicleMaintenanceCheckRecord({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.checkedAt,
    required this.createdAt,
    required this.updatedAt,
    this.checkedByUserId,
    this.odometer = 0,
    this.lastOilChangeAt,
    this.lastLubricantCheckAt,
    this.odometerAtLastService,
    this.brakeStatus = 'ok',
    this.batteryStatus = 'ok',
    this.notes = '',
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String vehicleId;
  @HiveField(3)
  final DateTime checkedAt;
  @HiveField(4)
  final String? checkedByUserId;
  @HiveField(5)
  final int odometer;
  @HiveField(6)
  final DateTime? lastOilChangeAt;
  @HiveField(7)
  final DateTime? lastLubricantCheckAt;
  @HiveField(8)
  final int? odometerAtLastService;
  @HiveField(9)
  final String brakeStatus;
  @HiveField(10)
  final String batteryStatus;
  @HiveField(11)
  final String notes;
  @HiveField(12)
  final DateTime createdAt;
  @HiveField(13)
  final DateTime updatedAt;
}

class VehicleMaintenanceCheckRecordAdapter
    extends TypeAdapter<VehicleMaintenanceCheckRecord> {
  @override
  final int typeId = kVehicleMaintenanceCheckTypeId;

  @override
  VehicleMaintenanceCheckRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleMaintenanceCheckRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      vehicleId: fields[2] as String,
      checkedAt: fields[3] as DateTime,
      checkedByUserId: fields[4] as String?,
      odometer: fields[5] as int? ?? 0,
      lastOilChangeAt: fields[6] as DateTime?,
      lastLubricantCheckAt: fields[7] as DateTime?,
      odometerAtLastService: fields[8] as int?,
      brakeStatus: fields[9] as String? ?? 'ok',
      batteryStatus: fields[10] as String? ?? 'ok',
      notes: fields[11] as String? ?? '',
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleMaintenanceCheckRecord value) {
    writer
      ..writeByte(14)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.vehicleId)
      ..writeByte(3)..write(value.checkedAt)
      ..writeByte(4)..write(value.checkedByUserId)
      ..writeByte(5)..write(value.odometer)
      ..writeByte(6)..write(value.lastOilChangeAt)
      ..writeByte(7)..write(value.lastLubricantCheckAt)
      ..writeByte(8)..write(value.odometerAtLastService)
      ..writeByte(9)..write(value.brakeStatus)
      ..writeByte(10)..write(value.batteryStatus)
      ..writeByte(11)..write(value.notes)
      ..writeByte(12)..write(value.createdAt)
      ..writeByte(13)..write(value.updatedAt);
  }
}
