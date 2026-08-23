import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/template_revision_lifecycle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23);
  final source = _definition(now);
  const lifecycle = TemplateRevisionLifecycle();

  test('only dispatch and supervisory roles can manage templates in the UI', () {
    expect(canManageTemplates(UserRole.tech), isFalse);
    expect(canManageTemplates(UserRole.dispatcher), isTrue);
    expect(canManageTemplates(UserRole.supervisor), isTrue);
    expect(canManageTemplates(UserRole.admin), isTrue);
  });

  test('cloning makes a new draft without sharing definition identifiers', () {
    var next = 0;
    final cloned = lifecycle.cloneAsDraft(
      source: source,
      existing: [source.revision],
      now: now.add(const Duration(days: 1)),
      idFactory: () => 'new-${next++}',
    );

    expect(cloned.revision.status, TemplateRevisionStatus.draft);
    expect(cloned.revision.revisionNumber, 2);
    expect(cloned.fields.single.id, isNot(source.fields.single.id));
    expect(cloned.fields.single.sectionId, cloned.sections.single.id);
    expect(cloned.options.single.fieldId, cloned.fields.single.id);
  });

  test('publishing archives the current live revision before replacement', () {
    final draft = lifecycle.cloneAsDraft(
      source: source,
      existing: [source.revision],
      now: now.add(const Duration(days: 1)),
      idFactory: _ids(),
    ).revision;
    final publication = lifecycle.publish(
      draft: draft,
      existing: [source.revision, draft],
      now: now.add(const Duration(days: 2)),
    );

    expect(publication.archiveFirst?.status, TemplateRevisionStatus.archived);
    expect(publication.published.status, TemplateRevisionStatus.published);
    expect(publication.published.publishedAt, now.add(const Duration(days: 2)));
  });
}

TemplateIdFactory _ids() {
  var value = 0;
  return () => 'id-${value++}';
}

FormTemplateDefinition _definition(DateTime now) {
  const tenantId = 'tenant-1';
  final template = FormTemplate(
    id: 'template-1',
    tenantId: tenantId,
    slug: 'generator-inspection',
    name: 'Generator inspection',
    assetType: 'generator',
    createdAt: now,
    updatedAt: now,
  );
  final revision = FormTemplateRevision(
    id: 'revision-1',
    tenantId: tenantId,
    templateId: template.id,
    revisionNumber: 1,
    status: TemplateRevisionStatus.published,
    title: 'Generator inspection',
    createdAt: now,
    updatedAt: now,
  );
  final section = FormTemplateSection(
    id: 'section-1',
    tenantId: tenantId,
    revisionId: revision.id,
    key: 'site',
    title: 'Site',
    position: 1,
  );
  final field = FormTemplateField(
    id: 'field-1',
    tenantId: tenantId,
    revisionId: revision.id,
    sectionId: section.id,
    key: 'site_grade',
    label: 'Site grade',
    type: TemplateFieldType.select,
    position: 1,
  );
  return FormTemplateDefinition(
    template: template,
    revision: revision,
    sections: [section],
    fields: [field],
    options: [
      FormTemplateFieldOption(
        id: 'option-1',
        tenantId: tenantId,
        fieldId: field.id,
        value: 'green',
        label: 'Green',
        position: 1,
      ),
    ],
  );
}
