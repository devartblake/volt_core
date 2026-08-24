import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/infra/repositories/form_response_repository.dart';
import 'package:voltcore/modules/templates/presenter/controllers/template_response_session_controller.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23);

  FormTemplateDefinition definition() => FormTemplateDefinition(
        template: FormTemplate(
          id: 'template',
          tenantId: 'tenant',
          slug: 'generator-inspection',
          name: 'Generator Inspection',
          assetType: 'generator',
          createdAt: now,
          updatedAt: now,
        ),
        revision: FormTemplateRevision(
          id: 'revision-1',
          tenantId: 'tenant',
          templateId: 'template',
          revisionNumber: 1,
          status: TemplateRevisionStatus.published,
          title: 'Inspection v1',
          createdAt: now,
          updatedAt: now,
        ),
        sections: const [
          FormTemplateSection(
            id: 'section',
            tenantId: 'tenant',
            revisionId: 'revision-1',
            key: 'main',
            title: 'Main',
            position: 0,
          ),
        ],
        fields: const [
          FormTemplateField(
            id: 'notes-field',
            tenantId: 'tenant',
            revisionId: 'revision-1',
            sectionId: 'section',
            key: 'notes',
            label: 'Notes',
            type: TemplateFieldType.text,
            position: 0,
            isRequired: true,
          ),
        ],
        options: const [],
      );

  FormResponse response({
    Map<String, dynamic> values = const {},
    TemplateResponseStatus status = TemplateResponseStatus.draft,
    String revisionId = 'revision-1',
  }) =>
      FormResponse(
        id: 'response-1',
        tenantId: 'tenant',
        templateId: 'template',
        templateRevisionId: revisionId,
        status: status,
        subjectType: 'asset',
        subjectId: 'asset-1',
        values: values,
        createdAt: now,
        updatedAt: now,
      );

  test('restores existing draft values after restart', () {
    final controller = TemplateResponseSessionController(
      definition: definition(),
      repository: _FakeFormResponseRepository(),
      response: response(values: const {'notes': 'saved offline'}),
    );
    addTearDown(controller.dispose);

    expect(controller.values['notes'], 'saved offline');
    expect(controller.isLocked, isFalse);
  });

  test('flush persists a revision-pinned draft', () async {
    final repository = _FakeFormResponseRepository();
    final controller = TemplateResponseSessionController(
      definition: definition(),
      repository: repository,
      response: response(),
      autosaveDelay: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    controller.setValue('notes', 'field reading recorded');
    await controller.flush();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.status, TemplateResponseStatus.draft);
    expect(repository.saved.single.templateRevisionId, 'revision-1');
    expect(repository.saved.single.values['notes'], 'field reading recorded');
  });

  test('completion is blocked when required values are invalid', () async {
    final repository = _FakeFormResponseRepository();
    final controller = TemplateResponseSessionController(
      definition: definition(),
      repository: repository,
      response: response(),
    );
    addTearDown(controller.dispose);

    final result = await controller.complete(completedByUserId: 'tech-1');

    expect(result.completed, isFalse);
    expect(result.issues, isNotEmpty);
    expect(controller.isLocked, isFalse);
    expect(repository.saved, isEmpty);
  });

  test('successful completion locks further mutation', () async {
    final repository = _FakeFormResponseRepository();
    final controller = TemplateResponseSessionController(
      definition: definition(),
      repository: repository,
      response: response(values: const {'notes': 'complete'}),
    );
    addTearDown(controller.dispose);

    final result = await controller.complete(completedByUserId: 'tech-1');

    expect(result.completed, isTrue);
    expect(controller.isLocked, isTrue);
    expect(repository.saved.single.status, TemplateResponseStatus.completed);
    expect(repository.saved.single.completedByUserId, 'tech-1');
    expect(
      () => controller.setValue('notes', 'changed after completion'),
      throwsStateError,
    );
  });

  test('rejects a response pinned to another revision', () {
    expect(
      () => TemplateResponseSessionController(
        definition: definition(),
        repository: _FakeFormResponseRepository(),
        response: response(revisionId: 'revision-2'),
      ),
      throwsArgumentError,
    );
  });
}

class _FakeFormResponseRepository implements FormResponseRepository {
  final List<FormResponse> saved = [];

  @override
  Future<FormResponse?> getById(String id) async {
    for (final response in saved.reversed) {
      if (response.id == id) return response;
    }
    return null;
  }

  @override
  Future<List<FormResponse>> list() async => List.unmodifiable(saved);

  @override
  Future<FormResponse> save(FormResponse response) async {
    saved.add(response);
    return response;
  }
}
