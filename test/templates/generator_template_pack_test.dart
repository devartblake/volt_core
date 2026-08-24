import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_template_pack.dart';
import 'package:voltcore/modules/templates/infra/mappers/legacy_generator_response_adapter.dart';
import 'package:voltcore/modules/templates/infra/repositories/template_definition_repository.dart';
import 'package:voltcore/modules/templates/infra/repositories/template_management_repository.dart';
import 'package:voltcore/modules/templates/infra/services/generator_template_pack_installer.dart';

void main() {
  const tenantId = 'tenant-a';
  final now = DateTime.utc(2026, 8, 23, 20);

  group('GeneratorTemplatePack', () {
    test('inspection pack preserves stable legacy semantic keys', () {
      final definition = GeneratorTemplatePack.inspection(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );

      expect(definition.template.slug, 'generator-inspection');
      expect(definition.revision.status, TemplateRevisionStatus.published);
      expect(definition.sections.map((item) => item.key), containsAll([
        'site_generator',
        'location_safety',
        'fdny_dep',
        'operational_use',
        'post_inspection',
        'service_history',
        'signatures',
      ]));
      expect(definition.fields.map((item) => item.key), containsAll([
        'siteCode',
        'generatorSerial',
        'fdnyPermit',
        'gensetRunsUnderLoad',
        'technicianSignaturePath',
      ]));
      expect(
        definition.revision.settings['externalLegacyCollections'],
        ['load_tests', 'photo_attachments'],
      );
    });

    test('maintenance pack covers legacy component/action/signature groups', () {
      final definition = GeneratorTemplatePack.maintenance(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );
      final keys = definition.fields.map((item) => item.key).toSet();

      expect(definition.template.slug, 'generator-maintenance');
      expect(keys, containsAll([
        'batteryNeedsReplace',
        'coolantHosesCompromised',
        'oilFilterChanged',
        'postVerifyRunsUnderLoad',
        'partsOilTypeQty',
        'requiresFollowUp',
        'customerSignaturePath',
      ]));
    });
  });

  group('LegacyGeneratorResponseAdapter', () {
    test('inspection preserves canonical values and complete raw provenance', () {
      final definition = GeneratorTemplatePack.inspection(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );
      final inspection = InspectionEntity(
        id: 'inspection-1',
        tenantId: tenantId,
        createdAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 21),
        serviceDate: DateTime.utc(2026, 8, 20),
        technicianSigDate: DateTime.utc(2026, 8, 20),
        customerSigDate: DateTime.utc(2026, 8, 20),
        siteCode: 'BK-101',
        address: '100 Test Ave',
        generatorSerial: 'GEN-001',
        areaClear: true,
        pdfPath: '/legacy/report.pdf',
      );

      final response = LegacyGeneratorResponseAdapter.inspection(
        source: inspection,
        definition: definition,
        responseId: 'response-1',
      );

      expect(response.templateRevisionId, definition.revision.id);
      expect(response.status, TemplateResponseStatus.completed);
      expect(response.values['siteCode'], 'BK-101');
      expect(response.values['areaClear'], true);
      final legacy = response.values['_legacy']! as Map<String, dynamic>;
      final payload = response.values['_legacyPayload']! as Map<String, dynamic>;
      expect(legacy['sourceId'], 'inspection-1');
      expect(legacy['validationEnforcedAtMigration'], false);
      expect(payload['pdfPath'], '/legacy/report.pdf');
    });

    test('maintenance draft/completed status follows the legacy record', () {
      final definition = GeneratorTemplatePack.maintenance(
        tenantId: tenantId,
        now: now,
        idFactory: (_) => const Uuid().v4(),
      );
      final record = MaintenanceRecord(
        id: 'maintenance-1',
        inspectionId: 'inspection-1',
        siteCode: 'BK-101',
        address: '100 Test Ave',
        oilFilterChanged: true,
        oilFilterNotes: 'Changed at service',
        requiresFollowUp: true,
        followUpNotes: 'Recheck hose',
        completed: false,
        createdAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 21),
      );

      final response = LegacyGeneratorResponseAdapter.maintenance(
        source: record,
        definition: definition,
        tenantId: tenantId,
        responseId: 'response-2',
      );

      expect(response.status, TemplateResponseStatus.draft);
      expect(response.inspectionId, 'inspection-1');
      expect(response.values['oilFilterChanged'], true);
      expect(response.values['followUpNotes'], 'Recheck hose');
      expect(response.values['_legacyPayload'], isA<Map<String, dynamic>>());
    });
  });

  test('installer installs only missing built-in slugs through draft/publish', () async {
    final definitions = _FakeDefinitions([
      FormTemplate(
        id: 'existing-template',
        tenantId: tenantId,
        slug: 'generator-inspection',
        name: 'Existing inspection',
        assetType: 'generator',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final management = _FakeManagement();
    final installer = GeneratorTemplatePackInstaller(
      definitions: definitions,
      management: management,
    );

    final installed = await installer.installMissing(tenantId: tenantId);

    expect(installed, ['generator-maintenance']);
    expect(management.saved, hasLength(1));
    expect(management.saved.single.template.slug, 'generator-maintenance');
    expect(management.saved.single.revision.status, TemplateRevisionStatus.draft);
    expect(management.published, [management.saved.single.revision.id]);
  });
}

class _FakeDefinitions implements TemplateDefinitionRepository {
  _FakeDefinitions(this.templates);
  final List<FormTemplate> templates;

  @override
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  }) async => null;

  @override
  Future<List<FormTemplate>> listTemplates() async => templates;
}

class _FakeManagement implements TemplateManagementRepository {
  final saved = <FormTemplateDefinition>[];
  final published = <String>[];

  @override
  Future<void> saveDraft(FormTemplateDefinition definition) async {
    saved.add(definition);
  }

  @override
  Future<void> publish(String revisionId) async {
    published.add(revisionId);
  }

  @override
  Future<void> archive(String revisionId) async {}

  @override
  Future<List<FormTemplateRevision>> listRevisions(String templateId) async => const [];
}
