import 'package:uuid/uuid.dart';

import '../../domain/entities/template_entities.dart';
import '../../domain/services/generator_template_pack.dart';
import '../repositories/template_definition_repository.dart';
import '../repositories/template_management_repository.dart';

/// Installs Voltcore's built-in generator templates through the same atomic
/// draft/publish boundary used by the management UI.
///
/// Existing slugs are left untouched. That makes installation safe for tenants
/// that have already started managing their own revisions and prevents a client
/// upgrade from silently replacing an operator-controlled template.
class GeneratorTemplatePackInstaller {
  GeneratorTemplatePackInstaller({
    required TemplateDefinitionRepository definitions,
    required TemplateManagementRepository management,
    Uuid uuid = const Uuid(),
  })  : _definitions = definitions,
        _management = management,
        _uuid = uuid;

  final TemplateDefinitionRepository _definitions;
  final TemplateManagementRepository _management;
  final Uuid _uuid;

  Future<List<String>> installMissing({required String tenantId}) async {
    final existing = await _definitions.listTemplates();
    final existingSlugs = existing.map((template) => template.slug).toSet();
    final installed = <String>[];

    if (!existingSlugs.contains('generator-inspection')) {
      await _install(
        GeneratorTemplatePack.inspection(
          tenantId: tenantId,
          now: DateTime.now().toUtc(),
          idFactory: (_) => _uuid.v4(),
        ),
      );
      installed.add('generator-inspection');
    }

    if (!existingSlugs.contains('generator-maintenance')) {
      await _install(
        GeneratorTemplatePack.maintenance(
          tenantId: tenantId,
          now: DateTime.now().toUtc(),
          idFactory: (_) => _uuid.v4(),
        ),
      );
      installed.add('generator-maintenance');
    }

    return installed;
  }

  Future<void> _install(FormTemplateDefinition publishedPack) async {
    final revision = publishedPack.revision;
    final draft = FormTemplateDefinition(
      template: publishedPack.template,
      revision: FormTemplateRevision(
        id: revision.id,
        tenantId: revision.tenantId,
        templateId: revision.templateId,
        revisionNumber: revision.revisionNumber,
        status: TemplateRevisionStatus.draft,
        title: revision.title,
        instructions: revision.instructions,
        settings: revision.settings,
        createdAt: revision.createdAt,
        updatedAt: revision.updatedAt,
      ),
      sections: publishedPack.sections,
      fields: publishedPack.fields,
      options: publishedPack.options,
    );

    await _management.saveDraft(draft);
    await _management.publish(draft.revision.id);
  }
}
