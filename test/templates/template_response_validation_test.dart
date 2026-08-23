import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/template_response_validation.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23);
  final template = FormTemplate(
    id: 'template-1',
    tenantId: 'tenant-1',
    slug: 'generator-inspection',
    name: 'Generator inspection',
    assetType: 'generator',
    createdAt: now,
    updatedAt: now,
  );
  final revision = FormTemplateRevision(
    id: 'revision-1',
    tenantId: 'tenant-1',
    templateId: template.id,
    revisionNumber: 1,
    status: TemplateRevisionStatus.published,
    title: 'Generator inspection',
    createdAt: now,
    updatedAt: now,
  );
  final section = FormTemplateSection(
    id: 'section-1',
    tenantId: 'tenant-1',
    revisionId: revision.id,
    key: 'site',
    title: 'Site',
    position: 1,
  );

  FormTemplateField field({
    required String id,
    required String key,
    required TemplateFieldType type,
    bool isRequired = false,
    Map<String, dynamic> validation = const {},
    Map<String, dynamic> visibilityRule = const {},
    int position = 1,
  }) =>
      FormTemplateField(
        id: id,
        tenantId: 'tenant-1',
        revisionId: revision.id,
        sectionId: section.id,
        key: key,
        label: key,
        type: type,
        position: position,
        isRequired: isRequired,
        validation: validation,
        visibilityRule: visibilityRule,
      );

  test('orders renderer metadata without mixing revisions', () {
    final definition = FormTemplateDefinition(
      template: template,
      revision: revision,
      sections: [section],
      fields: [
        field(
          id: 'field-2',
          key: 'later',
          type: TemplateFieldType.text,
          position: 2,
        ),
        field(id: 'field-1', key: 'first', type: TemplateFieldType.text),
      ],
      options: const [],
    );

    expect(definition.fieldsForSection(section.id).map((item) => item.key), [
      'first',
      'later',
    ]);
  });

  test('validates required, range, option, and conditional fields', () {
    final grade = field(
      id: 'grade',
      key: 'grade',
      type: TemplateFieldType.select,
      isRequired: true,
    );
    final kw = field(
      id: 'kw',
      key: 'kw',
      type: TemplateFieldType.number,
      validation: const {'min': 10, 'max': 500},
      position: 2,
    );
    final deficiency = field(
      id: 'deficiency',
      key: 'deficiency_notes',
      type: TemplateFieldType.text,
      isRequired: true,
      visibilityRule: const {'field': 'grade', 'equals': 'red'},
      position: 3,
    );
    final definition = FormTemplateDefinition(
      template: template,
      revision: revision,
      sections: [section],
      fields: [grade, kw, deficiency],
      options: [
        FormTemplateFieldOption(
          id: 'green',
          tenantId: 'tenant-1',
          fieldId: grade.id,
          value: 'green',
          label: 'Green',
          position: 1,
        ),
      ],
    );

    final issues = const TemplateResponseValidator().validate(
      definition: definition,
      values: const {'grade': 'red', 'kw': 600},
    );

    expect(issues.map((issue) => issue.fieldKey), [
      'grade',
      'kw',
      'deficiency_notes',
    ]);
  });
}
