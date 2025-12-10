import '../entities/maintenance_job_entity.dart';
import '../repositories/maintenance_repository.dart';

/// Parameters for creating a new maintenance job.
///
/// Not all params are currently persisted, but this gives us a stable contract
/// for the UI/controllers. We primarily map site/address/tech/notes/title.
class CreateMaintenanceParams {
  final String? id; // not used yet – repo generates ID via createDraft
  final String? inspectionId;

  /// Human-visible title – if null, we derive one from siteCode/address.
  final String? title;

  /// High-level notes (will map to [MaintenanceJobEntity.generalNotes]).
  final String? notes;

  /// Optional planned/scheduled date (not yet modeled on the entity).
  final DateTime? scheduledDate;

  /// Multitenancy hook – not yet modeled on the entity.
  final String? tenantId;

  final String siteCode;
  final String address;
  final String technician;

  const CreateMaintenanceParams({
    this.id,
    this.inspectionId,
    this.title,
    this.notes,
    this.scheduledDate,
    this.tenantId,
    this.siteCode = '',
    this.address = '',
    this.technician = '',
  });
}

/// Use case: create a new maintenance job.
///
/// This uses [MaintenanceRepository.createDraft] to generate a base job
/// (including ID + createdAt), then applies the given parameters via
/// [MaintenanceJobEntity.copyWith], and finally persists via [save].
class CreateMaintenanceUseCase {
  final MaintenanceRepository _repository;

  const CreateMaintenanceUseCase(this._repository);

  Future<MaintenanceJobEntity> call(CreateMaintenanceParams params) async {
    // Step 1: create a draft job from the repo
    final draft = await _repository.createDraft(
      inspectionId: params.inspectionId,
    );

    // Step 2: derive a title if none provided
    final derivedTitle = params.title ??
        (params.siteCode.isNotEmpty
            ? params.siteCode
            : (params.address.isNotEmpty
            ? params.address
            : 'Maintenance ${draft.id}'));

    final now = DateTime.now();

    // Step 3: build an updated entity with basic info
    final updated = draft.copyWith(
      siteCode: params.siteCode.isNotEmpty ? params.siteCode : draft.siteCode,
      address: params.address.isNotEmpty ? params.address : draft.address,
      technicianName:
      params.technician.isNotEmpty ? params.technician : draft.technicianName,
      generalNotes: params.notes ?? draft.generalNotes,
      title: derivedTitle,
      updatedAt: now,
    );

    // Step 4: persist & return
    await _repository.save(updated);
    return updated;
  }
}
