import '../entities/inspection_entity.dart';
import '../../infra/repositories/inspection_repository.dart';

class ListInspectionsUsecase {
  final InspectionRepository _repository;

  ListInspectionsUsecase(this._repository);

  Future<List<InspectionEntity>> call() {
    return _repository.listInspections();
  }
}
