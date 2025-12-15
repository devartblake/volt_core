import 'package:hive/hive.dart';

/// If you already have a conflicting typeId elsewhere, change this value.
/// Keep it stable once released.
const int kScheduledTaskTypeId = 72;

@HiveType(typeId: kScheduledTaskTypeId)
class ScheduledTask {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String tenantId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String? notes;

  @HiveField(4)
  final DateTime scheduledAt;

  @HiveField(5)
  final String status; // e.g. scheduled, completed, cancelled, overdue

  @HiveField(6)
  final String? assignedToUserId;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final String sourceType; // inspection, maintenance, manual, etc.

  @HiveField(10)
  final String? sourceId; // inspectionId / maintenanceJobId

  const ScheduledTask({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.scheduledAt,
    required this.status,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.assignedToUserId,
    this.sourceId,
  });

  ScheduledTask copyWith({
    String? id,
    String? tenantId,
    String? title,
    String? notes,
    DateTime? scheduledAt,
    String? status,
    String? assignedToUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourceType,
    String? sourceId,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}

/// Manual adapter so you do NOT need build_runner/hive_generator.
class ScheduledTaskAdapter extends TypeAdapter<ScheduledTask> {
  @override
  final int typeId = kScheduledTaskTypeId;

  @override
  ScheduledTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }

    return ScheduledTask(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      title: fields[2] as String,
      notes: fields[3] as String?,
      scheduledAt: fields[4] as DateTime,
      status: fields[5] as String,
      assignedToUserId: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      sourceType: fields[9] as String,
      sourceId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledTask obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.scheduledAt)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.assignedToUserId)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.sourceType)
      ..writeByte(10)
      ..write(obj.sourceId);
  }
}
