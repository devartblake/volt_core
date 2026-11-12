import 'package:hive/hive.dart';

/// Next free typeId after VehicleAssetRecord's 78.
const int kVehicleAssetCheckTypeId = 79;

/// ...and its lines.
const int kVehicleAssetCheckLineTypeId = 80;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kVehicleAssetCheckTypeId)
class VehicleAssetCheckRecord {
  const VehicleAssetCheckRecord({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.checkedAt,
    required this.disclaimerVersion,
    required this.createdAt,
    required this.updatedAt,
    this.operatorUserId,
    this.operatorName = '',
    this.coOperatorName = '',
    this.dispatcherUserId,
    this.dispatcherName = '',
    this.operatorSignaturePath,
    this.operatorSignedAt,
    this.dispatcherSignaturePath,
    this.dispatcherSignedAt,
    this.disclaimerAcceptedAt,
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
  final String? operatorUserId;
  @HiveField(5)
  final String operatorName;
  @HiveField(6)
  final String coOperatorName;
  @HiveField(7)
  final String? dispatcherUserId;
  @HiveField(8)
  final String dispatcherName;
  @HiveField(9)
  final String? operatorSignaturePath;
  @HiveField(10)
  final DateTime? operatorSignedAt;
  @HiveField(11)
  final String? dispatcherSignaturePath;
  @HiveField(12)
  final DateTime? dispatcherSignedAt;
  @HiveField(13)
  final int disclaimerVersion;
  @HiveField(14)
  final DateTime? disclaimerAcceptedAt;
  @HiveField(15)
  final String notes;
  @HiveField(16)
  final DateTime createdAt;
  @HiveField(17)
  final DateTime updatedAt;
}

class VehicleAssetCheckRecordAdapter
    extends TypeAdapter<VehicleAssetCheckRecord> {
  @override
  final int typeId = kVehicleAssetCheckTypeId;

  @override
  VehicleAssetCheckRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleAssetCheckRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      vehicleId: fields[2] as String,
      checkedAt: fields[3] as DateTime,
      operatorUserId: fields[4] as String?,
      operatorName: fields[5] as String? ?? '',
      coOperatorName: fields[6] as String? ?? '',
      dispatcherUserId: fields[7] as String?,
      dispatcherName: fields[8] as String? ?? '',
      operatorSignaturePath: fields[9] as String?,
      operatorSignedAt: fields[10] as DateTime?,
      dispatcherSignaturePath: fields[11] as String?,
      dispatcherSignedAt: fields[12] as DateTime?,
      // A receipt written before versioning existed cannot happen — the column
      // shipped with the table — but defaulting beats throwing on a row some
      // future migration truncates.
      disclaimerVersion: fields[13] as int? ?? 1,
      disclaimerAcceptedAt: fields[14] as DateTime?,
      notes: fields[15] as String? ?? '',
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleAssetCheckRecord value) {
    writer
      ..writeByte(18)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.vehicleId)
      ..writeByte(3)..write(value.checkedAt)
      ..writeByte(4)..write(value.operatorUserId)
      ..writeByte(5)..write(value.operatorName)
      ..writeByte(6)..write(value.coOperatorName)
      ..writeByte(7)..write(value.dispatcherUserId)
      ..writeByte(8)..write(value.dispatcherName)
      ..writeByte(9)..write(value.operatorSignaturePath)
      ..writeByte(10)..write(value.operatorSignedAt)
      ..writeByte(11)..write(value.dispatcherSignaturePath)
      ..writeByte(12)..write(value.dispatcherSignedAt)
      ..writeByte(13)..write(value.disclaimerVersion)
      ..writeByte(14)..write(value.disclaimerAcceptedAt)
      ..writeByte(15)..write(value.notes)
      ..writeByte(16)..write(value.createdAt)
      ..writeByte(17)..write(value.updatedAt);
  }
}

// ADDING A FIELD? Same rules as above.
@HiveType(typeId: kVehicleAssetCheckLineTypeId)
class VehicleAssetCheckLineRecord {
  const VehicleAssetCheckLineRecord({
    required this.id,
    required this.checkId,
    required this.tenantId,
    required this.assetName,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleAssetId,
    this.partNumber = '',
    this.serialNumber = '',
    this.quantity = 1,
    this.readiness = 'fmc',
    this.isMissing = false,
    this.reason = '',
    this.sortIndex = 0,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String checkId;
  @HiveField(2)
  final String tenantId;
  @HiveField(3)
  final String? vehicleAssetId;
  @HiveField(4)
  final String assetName;
  @HiveField(5)
  final String partNumber;
  @HiveField(6)
  final String serialNumber;
  @HiveField(7)
  final int quantity;
  @HiveField(8)
  final String readiness;
  @HiveField(9)
  final bool isMissing;
  @HiveField(10)
  final String reason;
  @HiveField(11)
  final int sortIndex;
  @HiveField(12)
  final DateTime createdAt;
  @HiveField(13)
  final DateTime updatedAt;
}

class VehicleAssetCheckLineRecordAdapter
    extends TypeAdapter<VehicleAssetCheckLineRecord> {
  @override
  final int typeId = kVehicleAssetCheckLineTypeId;

  @override
  VehicleAssetCheckLineRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return VehicleAssetCheckLineRecord(
      id: fields[0] as String,
      checkId: fields[1] as String,
      tenantId: fields[2] as String,
      vehicleAssetId: fields[3] as String?,
      assetName: fields[4] as String? ?? 'Unknown tool',
      partNumber: fields[5] as String? ?? '',
      serialNumber: fields[6] as String? ?? '',
      quantity: fields[7] as int? ?? 1,
      readiness: fields[8] as String? ?? 'fmc',
      isMissing: fields[9] as bool? ?? false,
      reason: fields[10] as String? ?? '',
      sortIndex: fields[11] as int? ?? 0,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleAssetCheckLineRecord value) {
    writer
      ..writeByte(14)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.checkId)
      ..writeByte(2)..write(value.tenantId)
      ..writeByte(3)..write(value.vehicleAssetId)
      ..writeByte(4)..write(value.assetName)
      ..writeByte(5)..write(value.partNumber)
      ..writeByte(6)..write(value.serialNumber)
      ..writeByte(7)..write(value.quantity)
      ..writeByte(8)..write(value.readiness)
      ..writeByte(9)..write(value.isMissing)
      ..writeByte(10)..write(value.reason)
      ..writeByte(11)..write(value.sortIndex)
      ..writeByte(12)..write(value.createdAt)
      ..writeByte(13)..write(value.updatedAt);
  }
}
