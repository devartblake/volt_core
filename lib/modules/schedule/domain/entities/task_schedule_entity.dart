import 'package:equatable/equatable.dart';

/// Domain entity representing a scheduled task (typically an inspection).
///
/// This is intentionally decoupled from the infra/Hive model and Supabase JSON.
/// Use mappers in infra to convert between this and your models/JSON.
class TaskScheduleEntity extends Equatable {
  final String id;

  /// When this task was created.
  final DateTime createdAt;

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

  /// Status: 'pending', 'completed', 'cancelled', etc.
  final String status;

  /// Multi-tenant support (optional).
  final String tenantId;

  const TaskScheduleEntity({
    required this.id,
    required this.createdAt,
    required this.scheduledDate,
    required this.title,
    this.description = '',
    this.inspectionId,
    this.siteCode = '',
    this.siteGrade = '',
    this.address = '',
    this.status = 'pending',
    this.tenantId = '',
  });

  TaskScheduleEntity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? scheduledDate,
    String? title,
    String? description,
    String? inspectionId,
    String? siteCode,
    String? siteGrade,
    String? address,
    String? status,
    String? tenantId,
  }) {
    return TaskScheduleEntity(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      title: title ?? this.title,
      description: description ?? this.description,
      inspectionId: inspectionId ?? this.inspectionId,
      siteCode: siteCode ?? this.siteCode,
      siteGrade: siteGrade ?? this.siteGrade,
      address: address ?? this.address,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
    scheduledDate,
    title,
    description,
    inspectionId,
    siteCode,
    siteGrade,
    address,
    status,
    tenantId,
  ];
}
