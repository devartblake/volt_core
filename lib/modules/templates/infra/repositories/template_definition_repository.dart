import '../../domain/entities/template_entities.dart';

abstract class TemplateDefinitionRepository {
  Future<List<FormTemplate>> listTemplates();

  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  });
}
