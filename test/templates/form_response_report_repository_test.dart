import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/infra/repositories/form_response_repository.dart';
import 'package:voltcore/modules/templates/infra/repositories/form_response_report_repository_impl.dart';

void main() {
  final now = DateTime.utc(2026, 9, 3, 19);

  FormResponse completedResponse() => FormResponse(
        id: '11111111-1111-4111-8111-111111111111',
        tenantId: '22222222-2222-4222-8222-222222222222',
        templateId: '33333333-3333-4333-8333-333333333333',
        templateRevisionId: '44444444-4444-4444-8444-444444444444',
        status: TemplateResponseStatus.completed,
        subjectType: 'inspection',
        customerId: '55555555-5555-4555-8555-555555555555',
        siteId: '66666666-6666-4666-8666-666666666666',
        assetId: '77777777-7777-4777-8777-777777777777',
        inspectionId: '88888888-8888-4888-8888-888888888888',
        values: const {},
        completedAt: now,
        completedByUserId: '99999999-9999-4999-8999-999999999999',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      );

  FormResponse draftResponse() {
    final value = completedResponse();
    return FormResponse(
      id: value.id,
      tenantId: value.tenantId,
      templateId: value.templateId,
      templateRevisionId: value.templateRevisionId,
      status: TemplateResponseStatus.draft,
      subjectType: value.subjectType,
      customerId: value.customerId,
      siteId: value.siteId,
      assetId: value.assetId,
      inspectionId: value.inspectionId,
      values: value.values,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
    );
  }

  test('create queues immutable server row and returns local response links',
      () async {
    final source = completedResponse();
    final queued = <Map<String, dynamic>>[];
    final ids = <String>[];
    final repository = FormResponseReportRepositoryImpl(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
      responses: _FakeResponses(source),
      queueWriter: (id, row) async {
        ids.add(id);
        queued.add(Map<String, dynamic>.from(row));
      },
      idFactory: (_, __) => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      clock: () => now,
    );

    final artifact = await repository.create(
      responseId: source.id,
      storagePath: 'pdfs/inspections/template_${source.id}.pdf',
      fileName: 'template_${source.id}.pdf',
      byteSize: 2048,
    );

    expect(ids, ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']);
    expect(queued, hasLength(1));
    expect(queued.single, {
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'response_id': source.id,
      'storage_path': 'pdfs/inspections/template_${source.id}.pdf',
      'file_name': 'template_${source.id}.pdf',
      'media_type': 'application/pdf',
      'byte_size': 2048,
    });
    expect(artifact.id, ids.single);
    expect(artifact.tenantId, source.tenantId);
    expect(artifact.templateRevisionId, source.templateRevisionId);
    expect(artifact.customerId, source.customerId);
    expect(artifact.siteId, source.siteId);
    expect(artifact.assetId, source.assetId);
    expect(artifact.inspectionId, source.inspectionId);
    expect(artifact.createdAt, now);
  });

  test('default artifact id is stable for the same response and path', () async {
    final source = completedResponse();
    final ids = <String>[];
    final repository = FormResponseReportRepositoryImpl(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
      responses: _FakeResponses(source),
      queueWriter: (id, _) async => ids.add(id),
      clock: () => now,
    );

    final first = await repository.create(
      responseId: source.id,
      storagePath: 'pdfs/inspections/report.pdf',
      fileName: 'report.pdf',
      byteSize: 10,
    );
    final second = await repository.create(
      responseId: source.id,
      storagePath: 'pdfs/inspections/report.pdf',
      fileName: 'report.pdf',
      byteSize: 10,
    );

    expect(first.id, second.id);
    expect(ids, [first.id, first.id]);
  });

  test('draft response cannot enqueue a report artifact', () async {
    var queued = false;
    final source = draftResponse();
    final repository = FormResponseReportRepositoryImpl(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
      responses: _FakeResponses(source),
      queueWriter: (_, __) async => queued = true,
    );

    await expectLater(
      repository.create(
        responseId: source.id,
        storagePath: 'pdfs/inspections/report.pdf',
        fileName: 'report.pdf',
        byteSize: 10,
      ),
      throwsStateError,
    );
    expect(queued, isFalse);
  });
}

class _FakeResponses implements FormResponseRepository {
  _FakeResponses(this.response);

  final FormResponse? response;

  @override
  Future<FormResponse?> getById(String id) async =>
      response?.id == id ? response : null;

  @override
  Future<List<FormResponse>> list() async =>
      response == null ? const [] : [response!];

  @override
  Future<FormResponse> save(FormResponse response) async => response;
}
