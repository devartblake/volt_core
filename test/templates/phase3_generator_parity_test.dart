import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/infra/mappers/legacy_generator_response_adapter.dart';
import 'package:voltcore/modules/templates/infra/services/template_pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tenantId = 'tenant-a';
  final now = DateTime.utc(2026, 8, 24, 12);

  test('inspection template fields retain a legacy evidence source', () {
    final definition = GeneratorTemplatePack.inspection(
      tenantId: tenantId,
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );
    final source = InspectionEntity(
      id: 'inspection-parity',
      tenantId: tenantId,
      createdAt: now,
      updatedAt: now,
      serviceDate: now,
      technicianSigDate: now,
      customerSigDate: now,
      siteCode: 'BK-101',
      address: '100 Test Ave',
      generatorSerial: 'GEN-001',
      siteGrade: 'Green',
      fdnyPermit: 'Yes',
      notes: 'Legacy parity record',
      technicianSignaturePath: 'signatures/tech.png',
      customerSignaturePath: 'signatures/customer.png',
    );

    final response = LegacyGeneratorResponseAdapter.inspection(
      source: source,
      definition: definition,
      responseId: 'response-inspection-parity',
    );
    final legacyPayload =
        response.values['_legacyPayload']! as Map<String, dynamic>;

    for (final field in definition.fields) {
      expect(
        response.values.containsKey(field.key) ||
            legacyPayload.containsKey(field.key),
        isTrue,
        reason: 'Inspection field ${field.key} lost its legacy evidence source.',
      );
    }

    final metadata = response.values['_legacy']! as Map<String, dynamic>;
    expect(metadata['validationEnforcedAtMigration'], isFalse);
    expect(metadata['booleanSemantics'], isNotEmpty);
    expect(metadata['externalCollections'], ['load_tests', 'photo_attachments']);
  });

  test('maintenance template fields retain a legacy evidence source', () {
    final definition = GeneratorTemplatePack.maintenance(
      tenantId: tenantId,
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );
    final source = MaintenanceRecord(
      id: 'maintenance-parity',
      inspectionId: 'inspection-parity',
      siteCode: 'BK-101',
      address: '100 Test Ave',
      generatorSerial: 'GEN-001',
      oilFilterChanged: true,
      oilFilterNotes: 'Changed',
      serviceObservations: 'Legacy maintenance parity record',
      completed: true,
      createdAt: now,
      updatedAt: now,
      technicianSignaturePath: 'signatures/tech.png',
      customerSignaturePath: 'signatures/customer.png',
    );

    final response = LegacyGeneratorResponseAdapter.maintenance(
      source: source,
      definition: definition,
      tenantId: tenantId,
      responseId: 'response-maintenance-parity',
    );
    final legacyPayload =
        response.values['_legacyPayload']! as Map<String, dynamic>;

    for (final field in definition.fields) {
      expect(
        response.values.containsKey(field.key) ||
            legacyPayload.containsKey(field.key),
        isTrue,
        reason: 'Maintenance field ${field.key} lost its legacy evidence source.',
      );
    }

    final metadata = response.values['_legacy']! as Map<String, dynamic>;
    expect(metadata['validationEnforcedAtMigration'], isFalse);
    expect(metadata['booleanSemantics'], isNotEmpty);
  });

  test('adapted generator inspection renders through generic report path',
      () async {
    final definition = GeneratorTemplatePack.inspection(
      tenantId: tenantId,
      now: now,
      idFactory: (_) => const Uuid().v4(),
    );
    final source = InspectionEntity(
      id: 'inspection-pdf-parity',
      tenantId: tenantId,
      createdAt: now,
      updatedAt: now,
      serviceDate: now,
      technicianSigDate: now,
      customerSigDate: now,
      siteCode: 'BK-102',
      address: '200 Test Ave',
      siteGrade: 'Amber',
      deficienciesDocumented: true,
      notes: 'Deficiency requires follow-up.',
    );
    final response = LegacyGeneratorResponseAdapter.inspection(
      source: source,
      definition: definition,
      responseId: 'response-pdf-parity',
    );

    final bytes = await const TemplatePdfReportService().build(
      definition: definition,
      response: response,
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
