import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/infra/services/template_pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds PDF bytes for a response pinned to the definition', () async {
    final now = DateTime.utc(2026, 8, 24);
    final definition = GeneratorTemplatePack.inspection(
      tenantId: 'tenant-a',
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );
    final response = FormResponse(
      id: 'response-1',
      tenantId: 'tenant-a',
      templateId: definition.template.id,
      templateRevisionId: definition.revision.id,
      status: TemplateResponseStatus.completed,
      subjectType: 'generator_inspection',
      subjectId: 'inspection-1',
      values: const {
        'siteCode': 'BK-101',
        'address': '100 Test Ave',
        'serviceDate': '2026-08-24',
        'siteGrade': 'Green',
        'areaClear': true,
        'deficienciesDocumented': false,
      },
      completedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await const TemplatePdfReportService().build(
      definition: definition,
      response: response,
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('rejects a response pinned to another revision', () async {
    final now = DateTime.utc(2026, 8, 24);
    final definition = GeneratorTemplatePack.inspection(
      tenantId: 'tenant-a',
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );
    final response = FormResponse(
      id: 'response-2',
      tenantId: 'tenant-a',
      templateId: definition.template.id,
      templateRevisionId: 'different-revision',
      status: TemplateResponseStatus.completed,
      subjectType: 'generator_inspection',
      values: const {},
      createdAt: now,
      updatedAt: now,
    );

    expect(
      () => const TemplatePdfReportService().build(
        definition: definition,
        response: response,
      ),
      throwsArgumentError,
    );
  });
}
