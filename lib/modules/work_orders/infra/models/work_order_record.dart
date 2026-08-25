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
    );
  }

  @override
  void write(BinaryWriter writer, WorkOrderRecord value) {
    writer
      ..writeByte(13)
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
      ..writeByte(12)..write(value.updatedAt);
  }
}
