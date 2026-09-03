import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/infra/services/template_report_storage_service.dart';

void main() {
  final now = DateTime.utc(2026, 9, 3, 20);

  FormResponse responseFor(FormTemplateDefinition definition) => FormResponse(
        id: const Uuid().v4(),
        tenantId: definition.template.tenantId,
        templateId: definition.template.id,
        templateRevisionId: definition.revision.id,
        status: TemplateResponseStatus.completed,
        subjectType: 'asset',
        values: const {},
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

  test('generator inspection slug classifies generic subject as inspection', () {
    final definition = GeneratorTemplatePack.inspection(
      tenantId: const Uuid().v4(),
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );

    expect(
      templateReportCategoryFor(
        definition: definition,
        response: responseFor(definition),
      ),
      TemplateReportCategory.inspection,
    );
  });

  test('generator maintenance slug classifies generic subject as maintenance', () {
    final definition = GeneratorTemplatePack.maintenance(
      tenantId: const Uuid().v4(),
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );

    expect(
      templateReportCategoryFor(
        definition: definition,
        response: responseFor(definition),
      ),
      TemplateReportCategory.maintenance,
    );
  });

  test('generic template still falls back to response relationships', () {
    final tenantId = const Uuid().v4();
    final templateId = const Uuid().v4();
    final revisionId = const Uuid().v4();
    final definition = FormTemplateDefinition(
      template: FormTemplate(
        id: templateId,
        tenantId: tenantId,
        slug: 'ats-inspection',
        name: 'ATS Inspection',
        assetType: 'ats',
        createdAt: now,
        updatedAt: now,
      ),
      revision: FormTemplateRevision(
        id: revisionId,
        tenantId: tenantId,
        templateId: templateId,
        revisionNumber: 1,
        status: TemplateRevisionStatus.published,
        title: 'ATS Inspection',
        createdAt: now,
        updatedAt: now,
      ),
      sections: const [],
      fields: const [],
      options: const [],
    );
    final generic = responseFor(definition);

    expect(
      templateReportCategoryFor(definition: definition, response: generic),
      TemplateReportCategory.other,
    );

    final linkedInspection = FormResponse(
      id: generic.id,
      tenantId: generic.tenantId,
      templateId: generic.templateId,
      templateRevisionId: generic.templateRevisionId,
      status: generic.status,
      subjectType: generic.subjectType,
      inspectionId: const Uuid().v4(),
      values: generic.values,
      completedAt: generic.completedAt,
      createdAt: generic.createdAt,
      updatedAt: generic.updatedAt,
    );
    expect(
      templateReportCategoryFor(
        definition: definition,
        response: linkedInspection,
      ),
      TemplateReportCategory.inspection,
    );
  });
}
