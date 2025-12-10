import '../entities/maintenance_job_entity.dart';
import '../repositories/maintenance_repository.dart';

/// High-level filter for listing maintenance jobs.
///
/// We keep it simple for now:
/// - all       → everything
/// - active    → !isCompleted
/// - archived  → isCompleted
enum MaintenanceListFilter {
  all,
  active,
  archived,
}

/// Use case: list maintenance jobs with basic filtering.
///
/// Infra only needs to implement [MaintenanceRepository.listAll]; we handle
/// simple filtering here in the domain layer.
class ListMaintenanceUseCase {
  final MaintenanceRepository _repository;

  const ListMaintenanceUseCase(this._repository);

  Future<List<MaintenanceJobEntity>> call({
    MaintenanceListFilter filter = MaintenanceListFilter.active,
  }) async {
    final all = await _repository.listAll();

    switch (filter) {
      case MaintenanceListFilter.all:
        return all;

      case MaintenanceListFilter.active:
        return all.where((job) => !job.isCompleted).toList();

      case MaintenanceListFilter.archived:
        return all.where((job) => job.isCompleted).toList();
    }
  }
}
