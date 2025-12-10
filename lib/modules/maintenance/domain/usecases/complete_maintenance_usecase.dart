import '../repositories/maintenance_repository.dart';

/// Use case for marking a maintenance job as completed.
class CompleteMaintenanceUseCase {
  final MaintenanceRepository _repository;

  const CompleteMaintenanceUseCase(this._repository);

  /// Mark job as completed.
  ///
  /// [completedAt] is optional; if omitted, the repository should
  /// default to `DateTime.now()`.
  Future<void> call(String jobId, {DateTime? completedAt}) {
    return _repository.completeJob(jobId, completedAt: completedAt);
  }
}