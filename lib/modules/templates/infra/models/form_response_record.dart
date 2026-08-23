import 'package:hive/hive.dart';

const int kFormResponseRecordTypeId = 74;

/// Hive representation of a generic template response.
///
/// The values snapshot stays JSON-compatible so it can be sent unchanged to
/// Supabase and, crucially, continues to describe the exact revision used.
@HiveType(typeId: kFormResponseRecordTypeId)
class FormResponseRecord {
  const FormResponseRecord({
    required this.id,
    required this.tenantId,
    required this.templateId,
    required this.templateRevisionId,
    required this.status,
    required this.subjectType,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.subjectId,
    this.customerId,
    this.siteId,
    this.assetId,
    this.workOrderId,
    this.inspectionId,
    this.maintenanceRecordId,
    this.completedAt,
    this.completedByUserId,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String templateId;
  @HiveField(3)
  final String templateRevisionId;
  @HiveField(4)
  final String status;
  @HiveField(5)
  final String subjectType;
  @HiveField(6)
  final String? subjectId;
  @HiveField(7)
  final String? customerId;
  @HiveField(8)
  final String? siteId;
  @HiveField(9)
  final String? assetId;
  @HiveField(10)
  final String? workOrderId;
  @HiveField(11)
  final String? inspectionId;
  @HiveField(12)
  final String? maintenanceRecordId;
  @HiveField(13)
  final Map<String, dynamic> values;
  @HiveField(14)
  final DateTime? completedAt;
  @HiveField(15)
  final String? completedByUserId;
  @HiveField(16)
  final DateTime createdAt;
  @HiveField(17)
  final DateTime updatedAt;
}

class FormResponseRecordAdapter extends TypeAdapter<FormResponseRecord> {
  @override
  final int typeId = kFormResponseRecordTypeId;

  @override
  FormResponseRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return FormResponseRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      templateId: fields[2] as String,
      templateRevisionId: fields[3] as String,
      status: fields[4] as String,
      subjectType: fields[5] as String,
      subjectId: fields[6] as String?,
      customerId: fields[7] as String?,
      siteId: fields[8] as String?,
      assetId: fields[9] as String?,
      workOrderId: fields[10] as String?,
      inspectionId: fields[11] as String?,
      maintenanceRecordId: fields[12] as String?,
      values: Map<String, dynamic>.from(fields[13] as Map? ?? const {}),
      completedAt: fields[14] as DateTime?,
      completedByUserId: fields[15] as String?,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FormResponseRecord value) {
    writer
      ..writeByte(18)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.templateId)
      ..writeByte(3)..write(value.templateRevisionId)
      ..writeByte(4)..write(value.status)
      ..writeByte(5)..write(value.subjectType)
      ..writeByte(6)..write(value.subjectId)
      ..writeByte(7)..write(value.customerId)
      ..writeByte(8)..write(value.siteId)
      ..writeByte(9)..write(value.assetId)
      ..writeByte(10)..write(value.workOrderId)
      ..writeByte(11)..write(value.inspectionId)
      ..writeByte(12)..write(value.maintenanceRecordId)
      ..writeByte(13)..write(value.values)
      ..writeByte(14)..write(value.completedAt)
      ..writeByte(15)..write(value.completedByUserId)
      ..writeByte(16)..write(value.createdAt)
      ..writeByte(17)..write(value.updatedAt);
  }
}
