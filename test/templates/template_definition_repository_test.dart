import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/infra/datasources/template_definition_remote_datasource.dart';
import 'package:voltcore/modules/templates/infra/repositories/template_definition_repository_impl.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync(
      'voltcore_template_definitions_',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('definitions');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('uses the cached pinned revision when a remote refresh fails', () async {
    final remote = _Remote(_definition());
    final repository = TemplateDefinitionRepositoryImpl(
      box: box,
      remote: remote,
      tenantIdReader: () => 'tenant-1',
    );

    final fresh = await repository.getDefinition('template-1');
    remote.fail = true;
    final cached = await repository.getDefinition('template-1');

    expect(fresh?.revision.id, 'revision-1');
    expect(cached?.revision.id, 'revision-1');
    expect(cached?.fields.single.key, 'site_grade');
  });

  test('does not return another tenant definition from the cache', () async {
    final repository = TemplateDefinitionRepositoryImpl(
      box: box,
      remote: _Remote(_definition(tenantId: 'tenant-2')),
      tenantIdReader: () => 'tenant-1',
    );

    expect(await repository.getDefinition('template-1'), isNull);
  });
}

class _Remote implements TemplateDefinitionRemoteDatasource {
  _Remote(this.definition);

  final FormTemplateDefinition definition;
  bool fail = false;

  @override
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  }) async {
    if (fail) throw StateError('offline');
    return templateId == definition.template.id ? definition : null;
  }

  @override
  Future<List<FormTemplate>> listTemplates() async {
    if (fail) throw StateError('offline');
    return [definition.template];
  }
}

FormTemplateDefinition _definition({String tenantId = 'tenant-1'}) {
  final now = DateTime.utc(2026, 8, 23);
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
  return FormTemplateDefinition(
    template: template,
    revision: revision,
    sections: [section],
    fields: [
      FormTemplateField(
        id: 'field-1',
        tenantId: tenantId,
        revisionId: revision.id,
        sectionId: section.id,
        key: 'site_grade',
        label: 'Site grade',
        type: TemplateFieldType.select,
        position: 1,
      ),
    ],
    options: const [],
  );
}
