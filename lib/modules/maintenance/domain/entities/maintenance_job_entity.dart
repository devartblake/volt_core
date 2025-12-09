
/// Domain-level representation of a maintenance job.
///
/// This is intentionally independent from Hive, Supabase, or any
/// persistence details. Infra layers (Hive models, API models) will
/// map *to/from* this entity.
class MaintenanceJobEntity {
  /// Unique job ID (matches your Hive `MaintenanceRecord.id`).
  final String id;

  /// Optional link back to an inspection.
  final String? inspectionId;

  /// Human-friendly title (e.g. "Monthly PM - RTU-03").
  final String? title;

  /// Free-form notes / details.
  final String? notes;

  /// When this job was created (locally or remotely).
  final DateTime createdAt;

  /// Last time the job was updated (any write).
  final DateTime? updatedAt;

  /// When the maintenance work is scheduled to occur.
  final DateTime? scheduledDate;

  /// When the maintenance work was marked as completed.
  final DateTime? completedAt;

  /// Whether the job is completed.
  final bool isCompleted;

  /// Whether the job is archived (e.g., hidden from the active list).
  final bool isArchived;

  /// Status string for UI badges and remote sync
  /// (e.g. "pending", "in_progress", "completed", "cancelled").
  final String status;

  /// Optional tenant identifier (for multi-tenant setups).
  final String? tenantId;

  /// Optional site code (e.g. "PS123-RTU3").
  final String? siteCode;

  /// Optional physical address of the job.
  final String? address;

  /// Optional technician / assignee name or ID.
  final String? technician;

  const MaintenanceJobEntity({
    required this.id,
    required this.createdAt,
    required this.status,
    this.inspectionId,
    this.title,
    this.notes,
    this.updatedAt,
    this.scheduledDate,
    this.completedAt,
    this.isCompleted = false,
    this.isArchived = false,
    this.tenantId,
    this.siteCode,
    this.address,
    this.technician,
  });

  /// Convenience factory for a brand-new job with sane defaults.
  /// The repository can still decide to override `id` during persistence.
  factory MaintenanceJobEntity.newJob({
    required String id,
    String? inspectionId,
    String? title,
    String? notes,
    DateTime? scheduledDate,
    String? tenantId,
    String? siteCode,
    String? address,
    String? technician,
  }) {
    final now = DateTime.now();
    return MaintenanceJobEntity(
      id: id,
      inspectionId: inspectionId,
      title: title,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      scheduledDate: scheduledDate,
      completedAt: null,
      isCompleted: false,
      isArchived: false,
      status: 'pending',
      tenantId: tenantId,
      siteCode: siteCode,
      address: address,
      technician: technician,
    );
  }

  MaintenanceJobEntity copyWith({
    String? id,
    String? inspectionId,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledDate,
    DateTime? completedAt,
    bool? isCompleted,
    bool? isArchived,
    String? status,
    String? tenantId,
    String? siteCode,
    String? address,
    String? technician,
  }) {
    return MaintenanceJobEntity(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      status: status ?? this.status,
      tenantId: tenantId ?? this.tenantId,
      siteCode: siteCode ?? this.siteCode,
      address: address ?? this.address,
      technician: technician ?? this.technician,
    );
  }
}