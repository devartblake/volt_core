import '../entities/inspection_entity.dart';
import '../../infra/repositories/inspection_repository.dart';

class CreateInspectionUsecase {
  final InspectionRepository _repository;

  CreateInspectionUsecase(this._repository);

  /// Creates a new inspection AND triggers PDF generation + email/export
  /// via the repository implementation.
  Future<InspectionEntity> call(InspectionEntity inspection) {
    return _repository.createInspection(inspection);
  }
}
