import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';

class ListUsersUsecase {
  final AdminRepository _repository;

  ListUsersUsecase(this._repository);

  Future<List<TechnicianEntity>> call() {
    return _repository.listTechnicians();
  }
}
