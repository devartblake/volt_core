import '../../domain/entities/task_schedule_entity.dart';

/// Infra model for schedule entries (used for JSON / local persistence).
///
/// You can later decorate this with Hive annotations if you want offline cache.
class ScheduleModel {
  final String id;
  final DateTime createdAt;
  final DateTime scheduledDate;
  final String title;
  final String description;
  final String? inspectionId;
  final String siteCode;
  final String siteGrade;
  final String address;
  final String status;
  final String tenantId;

  const ScheduleModel({
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

  factory ScheduleModel.fromEntity(TaskScheduleEntity e) {
    return ScheduleModel(
      id: e.id,
      createdAt: e.createdAt,
      scheduledDate: e.scheduledDate,
      title: e.title,
      description: e.description,
      inspectionId: e.inspectionId,
      siteCode: e.siteCode,
      siteGrade: e.siteGrade,
      address: e.address,
      status: e.status,
      tenantId: e.tenantId,
    );
  }

  TaskScheduleEntity toEntity() {
    return TaskScheduleEntity(
      id: id,
      createdAt: createdAt,
      scheduledDate: scheduledDate,
      title: title,
      description: description,
      inspectionId: inspectionId,
      siteCode: siteCode,
      siteGrade: siteGrade,
      address: address,
      status: status,
      tenantId: tenantId,
    );
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      scheduledDate:
      DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      inspectionId: json['inspection_id']?.toString(),
      siteCode: json['site_code'] ?? '',
      siteGrade: json['site_grade'] ?? '',
      address: json['address'] ?? '',
      status: json['status'] ?? 'pending',
      tenantId: json['tenant_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'scheduled_date': scheduledDate.toIso8601String(),
      'title': title,
      'description': description,
      'inspection_id': inspectionId,
      'site_code': siteCode,
      'site_grade': siteGrade,
      'address': address,
      'status': status,
      'tenant_id': tenantId,
    };
  }
}
