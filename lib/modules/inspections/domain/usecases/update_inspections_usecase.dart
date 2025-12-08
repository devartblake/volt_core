import '../entities/inspection_entity.dart';
import '../../infra/repositories/inspection_repository.dart';

class UpdateInspectionUsecase {
  final InspectionRepository _repository;

  UpdateInspectionUsecase(this._repository);

  /// Updates an inspection AND triggers PDF generation + email/export
  /// via the repository implementation.
  Future<InspectionEntity> call(InspectionEntity inspection) {
    return _repository.updateInspection(inspection);
  }
}
