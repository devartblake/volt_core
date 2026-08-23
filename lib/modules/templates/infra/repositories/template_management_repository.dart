import '../../domain/entities/template_entities.dart';

abstract class TemplateManagementRepository {
  Future<List<FormTemplateRevision>> listRevisions(String templateId);
  Future<void> saveDraft(FormTemplateDefinition definition);
  Future<void> publish(String revisionId);
  Future<void> archive(String revisionId);
}
