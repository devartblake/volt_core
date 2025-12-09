import '../../infra/repositories/maintenance_job_entity.dart';
import '../entities/maintenance_job_entity.dart';
import '../../infra/repositories/maintenance_repository.dart';

/// Input payload for creating a maintenance job.
///
/// You can expand this as needed instead of passing raw entities
/// from the UI.
class CreateMaintenanceParams {
  final String? id; // optional; repo may generate if null
  final String? inspectionId;
  final String? title;
  final String? notes;
  final DateTime? scheduledDate;
  final String? tenantId;
  final String? siteCode;
  final String? address;
  final String? technician;

  const CreateMaintenanceParams({
    this.id,
    this.inspectionId,
    this.title,
    this.notes,
    this.scheduledDate,
    this.tenantId,
    this.siteCode,
    this.address,
    this.technician,
  });
}

/// Use case for creating a new maintenance job.
///
/// UI/controllers will call this instead of talking directly to
/// the repository.
class CreateMaintenanceUseCase {
  final MaintenanceRepository _repository;

  const CreateMaintenanceUseCase(this._repository);

  Future<MaintenanceJobEntity> call(CreateMaintenanceParams params) async {
    // Let repo generate ID if caller didn’t.
    final id = params.id ?? _generateLocalId();

    final entity = MaintenanceJobEntity.newJob(
      id: id,
      inspectionId: params.inspectionId,
      title: params.title,
      notes: params.notes,
      scheduledDate: params.scheduledDate,
      tenantId: params.tenantId,
      siteCode: params.siteCode,
      address: params.address,
      technician: params.technician,
    );

    return _repository.create(entity);
  }

  /// Simple local ID helper. You can swap to UUID in infra if preferred.
  String _generateLocalId() {
    // e.g. "maint_20250101T120000_xxxx"
    final now = DateTime.now().toIso8601String();
    return 'maint_$now';
  }
}