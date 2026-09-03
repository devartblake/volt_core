import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/domain/services/template_revision_lifecycle.dart';
import 'package:voltcore/modules/templates/infra/mappers/legacy_generator_response_adapter.dart';
import 'package:voltcore/modules/templates/infra/repositories/form_response_repository.dart';
import 'package:voltcore/modules/templates/infra/services/template_pdf_report_service.dart';
import 'package:voltcore/modules/templates/infra/services/template_report_storage_service.dart';
import 'package:voltcore/modules/templates/presenter/controllers/template_response_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tenantId = 'tenant-phase3-certification';
  final now = DateTime.utc(2026, 9, 3, 18);

  group('Phase 3 generator pilot certification', () {
    test('inspection survives restart, completes, renders, and stays on v1',
        () async {
      final definition = GeneratorTemplatePack.inspection(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );

      await _certifyLifecycle(
        definition: definition,
        expectedCategory: TemplateReportCategory.inspection,
        now: now,
      );
    });

    test('maintenance survives restart, completes, renders, and stays on v1',
        () async {
      final definition = GeneratorTemplatePack.maintenance(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );

      await _certifyLifecycle(
        definition: definition,
        expectedCategory: TemplateReportCategory.maintenance,
        now: now,
      );
    });

    test('legacy inspection and maintenance still render through generic PDF path',
        () async {
      final inspectionDefinition = GeneratorTemplatePack.inspection(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );
      final maintenanceDefinition = GeneratorTemplatePack.maintenance(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );

      final inspection = InspectionEntity(
        id: 'legacy-inspection-certification',
        tenantId: tenantId,
        createdAt: now,
        updatedAt: now,
        serviceDate: now,
        technicianSigDate: now,
        customerSigDate: now,
        siteCode: 'CERT-I-001',
        address: '100 Certification Ave',
        generatorSerial: 'GEN-CERT-I',
        siteGrade: 'Amber',
        deficienciesDocumented: true,
        gensetRunsUnderLoad: true,
        voltageFrequencyOk: true,
        notes: 'Legacy inspection parity certification.',
        technicianSignaturePath: 'signatures/tech-cert.png',
        customerSignaturePath: 'signatures/customer-cert.png',
      );
      final inspectionResponse = LegacyGeneratorResponseAdapter.inspection(
        source: inspection,
        definition: inspectionDefinition,
        responseId: 'legacy-response-inspection-certification',
      );

      expect(inspectionResponse.values['siteCode'], 'CERT-I-001');
      expect(inspectionResponse.values['siteGrade'], 'Amber');
      expect(inspectionResponse.values['deficienciesDocumented'], isTrue);
      await _expectPdf(inspectionDefinition, inspectionResponse);

      final maintenance = MaintenanceRecord(
        id: 'legacy-maintenance-certification',
        inspectionId: inspection.id,
        siteCode: 'CERT-M-001',
        address: '200 Certification Ave',
        generatorSerial: 'GEN-CERT-M',
        batteryNeedsReplace: true,
        airFilterNeedsReplace: true,
        coolantLevel: 'Low',
        coolantHosesRecommendChange: true,
        oilFilterChanged: true,
        oilFilterNotes: 'Changed during certification.',
        serviceObservations: 'Legacy maintenance parity certification.',
        requiresFollowUp: true,
        followUpNotes: 'Return with replacement battery.',
        completed: true,
        createdAt: now,
        updatedAt: now,
        technicianSignaturePath: 'signatures/tech-cert.png',
        customerSignaturePath: 'signatures/customer-cert.png',
      );
      final maintenanceResponse = LegacyGeneratorResponseAdapter.maintenance(
        source: maintenance,
        definition: maintenanceDefinition,
        tenantId: tenantId,
        responseId: 'legacy-response-maintenance-certification',
      );

      expect(maintenanceResponse.values['siteCode'], 'CERT-M-001');
      expect(maintenanceResponse.values['batteryNeedsReplace'], isTrue);
      expect(maintenanceResponse.values['oilFilterChanged'], isTrue);
      await _expectPdf(maintenanceDefinition, maintenanceResponse);
    });
  });
}

Future<void> _certifyLifecycle({
  required FormTemplateDefinition definition,
  required TemplateReportCategory expectedCategory,
  required DateTime now,
}) async {
  final repository = _MemoryFormResponseRepository();
  final response = FormResponse(
    id: const Uuid().v4(),
    tenantId: definition.template.tenantId,
    templateId: definition.template.id,
    templateRevisionId: definition.revision.id,
    status: TemplateResponseStatus.draft,
    subjectType: 'asset',
    values: const {},
    createdAt: now,
    updatedAt: now,
  );

  final firstSession = TemplateResponseSessionController(
    definition: definition,
    repository: repository,
    response: response,
    autosaveDelay: const Duration(days: 1),
  );

  final certificationValues = _valuesFor(definition, now);
  for (final entry in certificationValues.entries) {
    firstSession.setValue(entry.key, entry.value);
  }
  await firstSession.flush();
  final savedDraft = await repository.getById(response.id);
  expect(savedDraft, isNotNull);
  expect(savedDraft!.status, TemplateResponseStatus.draft);
  expect(savedDraft.templateRevisionId, definition.revision.id);
  firstSession.dispose();

  // Simulate app/browser restart: a new session owns the locally saved response.
  final restartedSession = TemplateResponseSessionController(
    definition: definition,
    repository: repository,
    response: savedDraft,
  );
  addTearDown(restartedSession.dispose);

  expect(restartedSession.values, containsPair('siteCode', certificationValues['siteCode']));
  expect(restartedSession.response.templateRevisionId, definition.revision.id);

  final completion = await restartedSession.complete(
    completedByUserId: 'technician-certification',
  );
  expect(
    completion.issues,
    isEmpty,
    reason: completion.issues
        .map((issue) => '${issue.fieldKey}: ${issue.message}')
        .join(', '),
  );
  expect(completion.completed, isTrue);
  expect(restartedSession.isLocked, isTrue);
  expect(
    () => restartedSession.setValue('siteCode', 'MUTATED'),
    throwsStateError,
  );

  final completed = restartedSession.response;
  expect(completed.status, TemplateResponseStatus.completed);
  expect(completed.templateRevisionId, definition.revision.id);
  expect(
    templateReportCategoryFor(definition: definition, response: completed),
    expectedCategory,
  );
  await _expectPdf(definition, completed);

  // Publish a newer revision and prove the completed response still accepts
  // only its original immutable definition.
  const lifecycle = TemplateRevisionLifecycle();
  final draftV2 = lifecycle.cloneAsDraft(
    source: definition,
    existing: [definition.revision],
    idFactory: () => const Uuid().v4(),
    now: now.add(const Duration(days: 1)),
  );
  final publication = lifecycle.publish(
    draft: draftV2.revision,
    existing: [definition.revision, draftV2.revision],
    now: now.add(const Duration(days: 2)),
  );
  final revision2Definition = FormTemplateDefinition(
    template: draftV2.template,
    revision: publication.published,
    sections: draftV2.sections,
    fields: draftV2.fields,
    options: draftV2.options,
  );

  expect(publication.published.revisionNumber, 2);
  expect(publication.published.status, TemplateRevisionStatus.published);
  expect(
    () => TemplateResponseSessionController(
      definition: revision2Definition,
      repository: repository,
      response: completed,
    ),
    throwsArgumentError,
    reason: 'A completed revision-1 response must never reopen on revision 2.',
  );

  final originalRevisionSession = TemplateResponseSessionController(
    definition: definition,
    repository: repository,
    response: completed,
  );
  expect(originalRevisionSession.isLocked, isTrue);
  expect(originalRevisionSession.response.templateRevisionId, definition.revision.id);
  originalRevisionSession.dispose();
}

Map<String, dynamic> _valuesFor(
  FormTemplateDefinition definition,
  DateTime now,
) {
  final values = <String, dynamic>{};
  for (final field in definition.fields) {
    final options = definition.optionsForField(field.id);
    final allowed = field.validation['allowed'];
    final allowedValues = allowed is List ? allowed : const <Object?>[];

    values[field.key] = switch (field.type) {
      TemplateFieldType.text => switch (field.key) {
          'siteCode' => 'CERT-${definition.template.slug}',
          'address' => '100 Phase 3 Certification Ave',
          _ => 'Certification ${field.label}',
        },
      TemplateFieldType.number || TemplateFieldType.reading =>
        field.validation['min'] is num ? field.validation['min'] : 1,
      TemplateFieldType.date => now.toIso8601String(),
      TemplateFieldType.select => options.isNotEmpty
          ? options.first.value
          : (allowedValues.isNotEmpty ? allowedValues.first : 'Yes'),
      TemplateFieldType.boolean => true,
      TemplateFieldType.checklist => options.isNotEmpty
          ? <String>[options.first.value]
          : const <String>['certified'],
      TemplateFieldType.photo || TemplateFieldType.signature =>
        'evidence/${field.key}.png',
    };
  }
  return values;
}

Future<void> _expectPdf(
  FormTemplateDefinition definition,
  FormResponse response,
) async {
  final bytes = await const TemplatePdfReportService().build(
    definition: definition,
    response: response,
  );
  expect(bytes.length, greaterThan(1000));
  expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
}

class _MemoryFormResponseRepository implements FormResponseRepository {
  final Map<String, FormResponse> _responses = {};

  @override
  Future<FormResponse?> getById(String id) async => _responses[id];

  @override
  Future<List<FormResponse>> list() async => _responses.values.toList();

  @override
  Future<FormResponse> save(FormResponse response) async {
    final existing = _responses[response.id];
    if (existing != null) {
      if (existing.status == TemplateResponseStatus.completed) {
        throw StateError('Completed form responses are immutable.');
      }
      if (existing.templateId != response.templateId ||
          existing.templateRevisionId != response.templateRevisionId) {
        throw StateError('A response cannot move to another template revision.');
      }
    }
    _responses[response.id] = response;
    return response;
  }
}
