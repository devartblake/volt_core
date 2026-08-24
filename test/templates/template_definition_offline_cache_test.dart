import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/infra/datasources/template_definition_remote_datasource.dart';
import 'package:voltcore/modules/templates/infra/datasources/template_definitions_box.dart';
import 'package:voltcore/modules/templates/infra/repositories/template_definition_repository_impl.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voltcore_template_cache_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    TemplateDefinitionsBox.invalidate();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('offline fallback reopens only the exact cached revision', () async {
    final box = await Hive.openBox<dynamic>('definition_test');
    final definition = GeneratorTemplatePack.inspection(
      tenantId: 'tenant-a',
      now: DateTime.utc(2026, 8, 24),
      idFactory: (_) => const Uuid().v4(),
    );
    final remote = _FakeRemote(definition);
    final repository = TemplateDefinitionRepositoryImpl(
      box: box,
      remote: remote,
      tenantIdReader: () => 'tenant-a',
    );

    final online = await repository.getDefinition(
      definition.template.id,
      revisionId: definition.revision.id,
    );
    expect(online?.revision.id, definition.revision.id);

    remote.fail = true;
    final reopened = await repository.getDefinition(
      definition.template.id,
      revisionId: definition.revision.id,
    );
    expect(reopened?.revision.id, definition.revision.id);

    final otherRevision = await repository.getDefinition(
      definition.template.id,
      revisionId: const Uuid().v4(),
    );
    expect(
      otherRevision,
      isNull,
      reason: 'Offline fallback must never substitute a newer/other revision.',
    );
  });

  test('template definition cache survives close/reopen lifecycle', () async {
    await TemplateDefinitionsBox.init();
    await TemplateDefinitionsBox.box.put('sentinel', {'revision': 'rev-1'});

    await Hive.close();
    TemplateDefinitionsBox.invalidate();
    await TemplateDefinitionsBox.init();

    expect(TemplateDefinitionsBox.box.get('sentinel'), {'revision': 'rev-1'});
  });
}

class _FakeRemote implements TemplateDefinitionRemoteDatasource {
  _FakeRemote(this.definition);

  final FormTemplateDefinition definition;
  bool fail = false;

  @override
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  }) async {
    if (fail) throw StateError('offline');
    if (templateId != definition.template.id) return null;
    if (revisionId != null && revisionId != definition.revision.id) return null;
    return definition;
  }

  @override
  Future<List<FormTemplate>> listTemplates() async {
    if (fail) throw StateError('offline');
    return [definition.template];
  }
}
