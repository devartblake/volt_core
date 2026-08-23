 import 'package:equatable/equatable.dart';

/// Domain entity representing a scheduled task (typically an inspection).
///
/// This is intentionally decoupled from the infra/Hive model and Supabase JSON.
/// Use mappers in infra to convert between this and your models/JSON.
class TaskScheduleEntity extends Equatable {
  final String id;

  /// When this task was created.
  final DateTime createdAt;

  /// When this task was updated.
  final DateTime updatedAt;

  /// The date/time the inspection is scheduled to occur.
  final DateTime scheduledDate;

  /// Human-friendly title (e.g., address or site name).
  final String title;

  /// Optional detailed description.
  final String description;

  /// Optional link to an inspection (if this schedule represents an inspection).
  final String? inspectionId;

  /// Site code (used heavily in your UI).
  final String siteCode;

  /// Site grade: 'Green', 'Amber', 'Red', etc.
  final String siteGrade;

  /// Address for display in the schedule cards.
  final String address;

  /// When the task is scheduled to occur.
  final DateTime scheduledAt;

  /// Current workflow status.
  /// Keep as string for easy Supabase storage and forward compatibility:
  /// scheduled | in_progress | completed | cancelled
  final String status;

  /// Source linkage.
  /// inspection | maintenance_record | work_order | manual | other
  final String sourceType;

  /// ID of the source record (inspection id, maintenance id, etc.), when applicable.
  final String? sourceId;

  /// Assigned user (Supabase auth user id), when applicable.
  final String? assignedToUserId;

  /// Multi-tenant support (optional).
  final String tenantId;

  /// Notes
  final String? notes;

  const TaskScheduleEntity({
    required this.id,
    required this.scheduledAt,
    required this.updatedAt,
    required this.createdAt,
    required this.scheduledDate,
    required this.title,
    required this.sourceType,
    this.assignedToUserId,
    this.sourceId = '',
    this.description = '',
    this.inspectionId,
    this.siteCode = '',
    this.siteGrade = '',
    this.address = '',
    this.status = 'pending',
    this.tenantId = '',
    this.notes,
  });

  TaskScheduleEntity copyWith({
    String? id,
    DateTime? scheduledAt,
    DateTime? updatedAt,
    DateTime? createdAt,
    DateTime? scheduledDate,
    String? title,
    String? sourceType,
    String? assignToUserId,
    String? sourceId,
    String? description,
    String? inspectionId,
    String? siteCode,
    String? siteGrade,
    String? address,
    String? status,
    String? tenantId,
    String? notes,
  }) {
    return TaskScheduleEntity(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      title: title ?? this.title,
      description: description ?? this.description,
      inspectionId: inspectionId ?? this.inspectionId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      assignedToUserId: assignToUserId ?? assignedToUserId,
      siteCode: siteCode ?? this.siteCode,
      siteGrade: siteGrade ?? this.siteGrade,
      address: address ?? this.address,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    scheduledAt,
    updatedAt,
    createdAt,
    scheduledDate,
    title,
    description,
    inspectionId,
    sourceType,
    sourceId,
    assignedToUserId,
    siteCode,
    siteGrade,
    address,
    status,
    tenantId,
    notes,
  ];
}
