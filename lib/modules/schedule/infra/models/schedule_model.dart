import '../../domain/entities/task_schedule_entity.dart';

/// Infra model for schedule entries (used for JSON / local persistence).
///
/// You can later decorate this with Hive annotations if you want offline cache.
class ScheduleTaskModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime scheduledDate;
  final DateTime scheduledAt;
  final String title;
  final String description;
  final String? inspectionId;
  final String siteCode;
  final String siteGrade;
  final String address;
  final String status;
  final String tenantId;
  final String sourceType;

  const ScheduleTaskModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceType,
    required this.scheduledDate,
    required this.scheduledAt,
    required this.title,
    this.description = '',
    this.inspectionId,
    this.siteCode = '',
    this.siteGrade = '',
    this.address = '',
    this.status = 'pending',
    this.tenantId = '',
  });

  factory ScheduleTaskModel.fromEntity(TaskScheduleEntity e) {
    return ScheduleTaskModel(
      id: e.id,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      scheduledDate: e.scheduledDate,
      scheduledAt: e.scheduledAt,
      title: e.title,
      description: e.description,
      inspectionId: e.inspectionId,
      siteCode: e.siteCode,
      siteGrade: e.siteGrade,
      address: e.address,
      status: e.status,
      tenantId: e.tenantId,
      sourceType: e.sourceType,
    );
  }

  TaskScheduleEntity toEntity() {
    return TaskScheduleEntity(
      id: id,
      updatedAt: updatedAt,
      createdAt: createdAt,
      scheduledDate: scheduledDate,
      scheduledAt: scheduledAt,
      title: title,
      description: description,
      inspectionId: inspectionId,
      siteCode: siteCode,
      siteGrade: siteGrade,
      address: address,
      status: status,
      tenantId: tenantId,
      sourceType: sourceType,
    );
  }

  factory ScheduleTaskModel.fromJson(Map<String, dynamic> json) {
    return ScheduleTaskModel(
      id: json['id'].toString(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      scheduledAt: DateTime.tryParse(json['schedule_at'] ?? '') ?? DateTime.now(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      inspectionId: json['inspection_id']?.toString(),
      siteCode: json['site_code'] ?? '',
      siteGrade: json['site_grade'] ?? '',
      address: json['address'] ?? '',
      status: json['status'] ?? 'pending',
      tenantId: json['tenant_id'] ?? '',
      sourceType: json['source_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'update_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'scheduled_date': scheduledDate.toIso8601String(),
      'schedule_at': scheduledAt.toIso8601String(),
      'title': title,
      'description': description,
      'inspection_id': inspectionId,
      'site_code': siteCode,
      'site_grade': siteGrade,
      'address': address,
      'status': status,
      'tenant_id': tenantId,
      'source_type': sourceType,
    };
  }
}
