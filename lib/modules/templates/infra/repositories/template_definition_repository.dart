import '../../domain/entities/template_entities.dart';

abstract class TemplateDefinitionRepository {
  Future<List<FormTemplate>> listTemplates();

  /// Loads a specific revision when [revisionId] is supplied, otherwise the
  /// current published revision. A cached immutable definition is used when a
  /// remote refresh is unavailable.
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  });
}
