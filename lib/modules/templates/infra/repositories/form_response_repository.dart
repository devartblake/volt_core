import '../../domain/entities/template_entities.dart';

abstract class FormResponseRepository {
  Future<List<FormResponse>> list();
  Future<FormResponse?> getById(String id);
  Future<FormResponse> save(FormResponse response);
}
