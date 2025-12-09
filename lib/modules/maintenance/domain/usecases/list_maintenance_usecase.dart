import '../entities/maintenance_job_entity.dart';
import '../../infra/repositories/maintenance_repository.dart';

/// What kind of list the caller wants.
enum MaintenanceListFilter {
  all,
  active,
  archived,
}

/// Use case for listing maintenance jobs.
///
/// Keeps filtering logic in the domain layer instead of sprinkling it
/// across multiple widgets.
class ListMaintenanceUseCase {
  final MaintenanceRepository _repository;

  const ListMaintenanceUseCase(this._repository);

  Future<List<MaintenanceJobEntity>> call({
    MaintenanceListFilter filter = MaintenanceListFilter.active,
  }) async {
    switch (filter) {
      case MaintenanceListFilter.all:
        return _repository.listAll(includeArchived: true);
      case MaintenanceListFilter.active:
        return _repository.listActive();
      case MaintenanceListFilter.archived:
        return _repository.listArchived();
    }
  }
}