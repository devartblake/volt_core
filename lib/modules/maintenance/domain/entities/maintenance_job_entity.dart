import 'package:equatable/equatable.dart';

/// Pure domain model for a maintenance job.
///
/// This is a simplified “summary” view of the very detailed MaintenanceRecord.
/// We only pull what we need for lists/filters/forms.
class MaintenanceJobEntity extends Equatable {
  final String id;
  final String? inspectionId;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final bool isCompleted;
  final DateTime? completedAt;

  final bool requiresFollowUp;
  final String? followUpNotes;

  final String siteCode;
  final String address;
  final String technicianName;

  /// High-level notes or summary (mapped from [MaintenanceRecord.generalNotes]).
  final String? generalNotes;

  /// Computed “title” (e.g. Site XXX or address) – not persisted as its own field.
  final String title;

  const MaintenanceJobEntity({
    required this.id,
    required this.createdAt,
    required this.siteCode,
    required this.address,
    required this.technicianName,
    required this.title,
    this.inspectionId,
    this.updatedAt,
    this.isCompleted = false,
    this.completedAt,
    this.requiresFollowUp = false,
    this.followUpNotes,
    this.generalNotes,
  });

  MaintenanceJobEntity copyWith({
    String? id,
    String? inspectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    DateTime? completedAt,
    bool? requiresFollowUp,
    String? followUpNotes,
    String? siteCode,
    String? address,
    String? technicianName,
    String? generalNotes,
    String? title,
  }) {
    return MaintenanceJobEntity(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      requiresFollowUp: requiresFollowUp ?? this.requiresFollowUp,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      siteCode: siteCode ?? this.siteCode,
      address: address ?? this.address,
      technicianName: technicianName ?? this.technicianName,
      generalNotes: generalNotes ?? this.generalNotes,
      title: title ?? this.title,
    );
  }

  @override
  List<Object?> get props => [
    id,
    inspectionId,
    createdAt,
    updatedAt,
    isCompleted,
    completedAt,
    requiresFollowUp,
    followUpNotes,
    siteCode,
    address,
    technicianName,
    generalNotes,
    title,
  ];
}
