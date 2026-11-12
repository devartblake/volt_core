import 'package:hive/hive.dart';

const int kWorkOrderRecordTypeId = 73;

// ADDING A FIELD? It must tolerate being absent.
//
// This adapter is written by hand, so read the new field defensively —
// `fields[n] as String? ?? ''`, never a bare cast. Rows already on a
// technician's device carry no entry for it, and a bare cast throws on null,
// failing the whole record rather than just the new column. Remember the
// leading writeByte(count) too.
// test/storage/hive_adapter_forward_compat_test.dart enforces this; update
// its currentFieldCount for this model and leave fieldCountAtLastRelease.
@HiveType(typeId: kWorkOrderRecordTypeId)
class WorkOrderRecord {
  const WorkOrderRecord({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.siteId,
    this.assetId,
    this.assignedToUserId,
    this.scheduledFor,
    this.description = '',
    this.vehicleId,
    this.assetCheckLineId,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String status;
  @HiveField(4)
  final String priority;
  @HiveField(5)
  final String? customerId;
  @HiveField(6)
  final String? siteId;
  @HiveField(7)
  final String? assetId;
  @HiveField(8)
  final String? assignedToUserId;
  @HiveField(9)
  final DateTime? scheduledFor;
  @HiveField(10)
  final String description;
  @HiveField(11)
  final DateTime createdAt;
  @HiveField(12)
  final DateTime updatedAt;

  /// The van this work order is about, when it came from a fleet receipt.
  @HiveField(13)
  final String? vehicleId;

  /// The receipt line that raised it — "WERNER 8FT LADDER, missing, left on
  /// site". Without it the only link would be words typed into the title.
  @HiveField(14)
  final String? assetCheckLineId;
}

class WorkOrderRecordAdapter extends TypeAdapter<WorkOrderRecord> {
  @override
  final int typeId = kWorkOrderRecordTypeId;

  @override
  WorkOrderRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return WorkOrderRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      title: fields[2] as String,
      status: fields[3] as String,
      priority: fields[4] as String,
      customerId: fields[5] as String?,
      siteId: fields[6] as String?,
      assetId: fields[7] as String?,
      assignedToUserId: fields[8] as String?,
      scheduledFor: fields[9] as DateTime?,
      description: fields[10] as String? ?? '',
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      vehicleId: fields[13] as String?,
      assetCheckLineId: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkOrderRecord value) {
    writer
      ..writeByte(15)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.title)
      ..writeByte(3)..write(value.status)
      ..writeByte(4)..write(value.priority)
      ..writeByte(5)..write(value.customerId)
      ..writeByte(6)..write(value.siteId)
      ..writeByte(7)..write(value.assetId)
      ..writeByte(8)..write(value.assignedToUserId)
      ..writeByte(9)..write(value.scheduledFor)
      ..writeByte(10)..write(value.description)
      ..writeByte(11)..write(value.createdAt)
      ..writeByte(12)..write(value.updatedAt)
      ..writeByte(13)..write(value.vehicleId)
      ..writeByte(14)..write(value.assetCheckLineId);
  }
}
