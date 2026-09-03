import '../entities/template_entities.dart';
import 'generator_pilot_readiness.dart';

/// A locally persisted generator-pilot draft that can be reopened safely.
class GeneratorPilotResumeItem {
  const GeneratorPilotResumeItem({
    required this.response,
    required this.template,
  });

  final FormResponse response;
  final FormTemplate template;
}

/// Pure, tenant-safe filtering for generator pilot drafts.
///
/// The presenter supplies locally persisted responses plus locally/remote
/// resolved templates. Only draft responses for the active tenant and the two
/// certified generator pilot slugs are returned. Completed evidence is never
/// offered as an editable resume target.
class GeneratorPilotResumeService {
  const GeneratorPilotResumeService._();

  static List<GeneratorPilotResumeItem> drafts({
    required String tenantId,
    required Iterable<FormResponse> responses,
    required Iterable<FormTemplate> templates,
  }) {
    if (tenantId.isEmpty) return const [];

    final templatesById = <String, FormTemplate>{};
    for (final template in templates) {
      if (template.tenantId != tenantId || template.isArchived) continue;
      if (template.slug != GeneratorPilotReadiness.inspectionSlug &&
          template.slug != GeneratorPilotReadiness.maintenanceSlug) {
        continue;
      }
      templatesById[template.id] = template;
    }

    final items = <GeneratorPilotResumeItem>[];
    for (final response in responses) {
      if (response.tenantId != tenantId ||
          response.status != TemplateResponseStatus.draft) {
        continue;
      }
      final template = templatesById[response.templateId];
      if (template == null) continue;
      items.add(GeneratorPilotResumeItem(response: response, template: template));
    }

    items.sort(
      (first, second) =>
          second.response.updatedAt.compareTo(first.response.updatedAt),
    );
    return List.unmodifiable(items);
  }
}
