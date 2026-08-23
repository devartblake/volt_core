import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/infra/models/form_response_record.dart';
import 'package:voltcore/modules/templates/infra/repositories/form_response_repository_impl.dart';

void main() {
  late Box<FormResponseRecord> box;
  late Directory directory;

  setUpAll(() {
    Hive.registerAdapter(FormResponseRecordAdapter());
  });

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('voltcore_template_responses_');
    Hive.init(directory.path);
    box = await Hive.openBox<FormResponseRecord>('responses');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  FormResponse response({TemplateResponseStatus status = TemplateResponseStatus.draft}) {
    final now = DateTime.utc(2026, 8, 23);
    return FormResponse(
      id: 'response-1',
      tenantId: 'tenant-1',
      templateId: 'template-1',
      templateRevisionId: 'revision-1',
      status: status,
      subjectType: 'asset',
      assetId: 'asset-1',
      values: const {'hours': 250},
      createdAt: now,
      updatedAt: now,
    );
  }

  test('writes locally and queues a generic response for sync', () async {
    FormResponse? queued;
    final repository = FormResponseRepositoryImpl(
      box: box,
      tenantIdReader: () => 'tenant-1',
      queueWriter: (value) async => queued = value,
    );

    final saved = await repository.save(response());

    expect((await repository.list()).single.id, saved.id);
    expect(queued?.templateRevisionId, 'revision-1');
  });

  test('does not overwrite a completed response locally', () async {
    final repository = FormResponseRepositoryImpl(
      box: box,
      tenantIdReader: () => 'tenant-1',
      queueWriter: (_) async {},
    );
    await repository.save(response(status: TemplateResponseStatus.completed));

    await expectLater(repository.save(response()), throwsA(isA<StateError>()));
  });

  test('keeps the revision pinned after a draft is created', () async {
    final repository = FormResponseRepositoryImpl(
      box: box,
      tenantIdReader: () => 'tenant-1',
      queueWriter: (_) async {},
    );
    await repository.save(response());
    final moved = FormResponse(
      id: 'response-1',
      tenantId: 'tenant-1',
      templateId: 'template-1',
      templateRevisionId: 'revision-2',
      status: TemplateResponseStatus.draft,
      subjectType: 'asset',
      values: const <String, dynamic>{},
      createdAt: DateTime.utc(2026, 8, 23),
      updatedAt: DateTime.utc(2026, 8, 23),
    );

    await expectLater(repository.save(moved), throwsA(isA<StateError>()));
  });
}
