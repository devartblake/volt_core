import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/template_response_validation.dart';
import 'package:voltcore/modules/templates/presenter/widgets/template_form_renderer.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23);

  FormTemplateDefinition definition() {
    const tenantId = '00000000-0000-0000-0000-000000000001';
    const templateId = '00000000-0000-0000-0000-000000000002';
    const revisionId = '00000000-0000-0000-0000-000000000003';
    const sectionId = '00000000-0000-0000-0000-000000000004';
    const conditionalSectionId = '00000000-0000-0000-0000-000000000005';
    const enabledFieldId = '00000000-0000-0000-0000-000000000006';
    const notesFieldId = '00000000-0000-0000-0000-000000000007';
    const selectFieldId = '00000000-0000-0000-0000-000000000008';
    const followUpFieldId = '00000000-0000-0000-0000-000000000009';

    return FormTemplateDefinition(
      template: FormTemplate(
        id: templateId,
        tenantId: tenantId,
        slug: 'runtime-test',
        name: 'Runtime Test',
        assetType: 'generator',
        createdAt: now,
        updatedAt: now,
      ),
      revision: FormTemplateRevision(
        id: revisionId,
        tenantId: tenantId,
        templateId: templateId,
        revisionNumber: 1,
        status: TemplateRevisionStatus.published,
        title: 'Runtime Test v1',
        instructions: 'Complete every visible field.',
        createdAt: now,
        updatedAt: now,
      ),
      sections: const [
        FormTemplateSection(
          id: sectionId,
          tenantId: tenantId,
          revisionId: revisionId,
          key: 'main',
          title: 'Main section',
          position: 0,
        ),
        FormTemplateSection(
          id: conditionalSectionId,
          tenantId: tenantId,
          revisionId: revisionId,
          key: 'conditional',
          title: 'Conditional section',
          position: 1,
          visibilityRule: {'field': 'enabled', 'equals': true},
        ),
      ],
      fields: const [
        FormTemplateField(
          id: enabledFieldId,
          tenantId: tenantId,
          revisionId: revisionId,
          sectionId: sectionId,
          key: 'enabled',
          label: 'Enabled',
          type: TemplateFieldType.boolean,
          position: 0,
        ),
        FormTemplateField(
          id: notesFieldId,
          tenantId: tenantId,
          revisionId: revisionId,
          sectionId: sectionId,
          key: 'notes',
          label: 'Notes',
          type: TemplateFieldType.text,
          position: 1,
          isRequired: true,
        ),
        FormTemplateField(
          id: selectFieldId,
          tenantId: tenantId,
          revisionId: revisionId,
          sectionId: sectionId,
          key: 'condition',
          label: 'Condition',
          type: TemplateFieldType.select,
          position: 2,
        ),
        FormTemplateField(
          id: followUpFieldId,
          tenantId: tenantId,
          revisionId: revisionId,
          sectionId: conditionalSectionId,
          key: 'follow_up',
          label: 'Follow up',
          type: TemplateFieldType.text,
          position: 0,
          visibilityRule: {'field': 'condition', 'equals': 'fail'},
        ),
      ],
      options: const [
        FormTemplateFieldOption(
          id: '00000000-0000-0000-0000-000000000010',
          tenantId: tenantId,
          fieldId: selectFieldId,
          value: 'pass',
          label: 'Pass',
          position: 0,
        ),
        FormTemplateFieldOption(
          id: '00000000-0000-0000-0000-000000000011',
          tenantId: tenantId,
          fieldId: selectFieldId,
          value: 'fail',
          label: 'Fail',
          position: 1,
        ),
      ],
    );
  }

  testWidgets('renders only sections and fields visible for current values',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemplateFormRenderer(
            definition: definition(),
            values: const {'enabled': false, 'condition': 'fail'},
            onChanged: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('Main section'), findsOneWidget);
    expect(find.text('Conditional section'), findsNothing);
    expect(find.text('Follow up'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemplateFormRenderer(
            definition: definition(),
            values: const {'enabled': true, 'condition': 'fail'},
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conditional section'), findsOneWidget);
    expect(find.text('Follow up'), findsOneWidget);
  });

  testWidgets('emits field-key value changes', (tester) async {
    String? changedKey;
    Object? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemplateFormRenderer(
            definition: definition(),
            values: const {},
            onChanged: (key, value) {
              changedKey = key;
              changedValue = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Notes *'), 'ok');
    expect(changedKey, 'notes');
    expect(changedValue, 'ok');
  });

  testWidgets('surfaces validator issues beside their fields', (tester) async {
    const validator = TemplateResponseValidator();
    final currentDefinition = definition();
    final issues = validator.validate(
      definition: currentDefinition,
      values: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemplateFormRenderer(
            definition: currentDefinition,
            values: const {},
            validationIssues: issues,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('This field is required.'), findsOneWidget);
  });

  testWidgets('read-only mode disables interactive inputs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemplateFormRenderer(
            definition: definition(),
            values: const {'enabled': true, 'notes': 'locked'},
            readOnly: true,
            onChanged: (_, __) => fail('read-only renderer emitted a change'),
          ),
        ),
      ),
    );

    final notes = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Notes *'),
    );
    expect(notes.enabled, isFalse);
  });
}
