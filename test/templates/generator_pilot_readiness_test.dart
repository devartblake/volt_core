import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_pilot_readiness.dart';

void main() {
  const tenantId = 'tenant-a';
  final now = DateTime.utc(2026, 9, 3);

  FormTemplate template(String id, String slug, {String tenant = tenantId}) =>
      FormTemplate(
        id: id,
        tenantId: tenant,
        slug: slug,
        name: slug,
        assetType: 'generator',
        createdAt: now,
        updatedAt: now,
      );

  FormTemplateRevision revision(
    String id,
    String templateId,
    TemplateRevisionStatus status, {
    int number = 1,
  }) => FormTemplateRevision(
    id: id,
    tenantId: tenantId,
    templateId: templateId,
    revisionNumber: number,
    status: status,
    title: 'Revision $number',
    createdAt: now,
    updatedAt: now,
  );

  test('fully ready requires tenant, pilot flag, and one published revision per pack', () {
    final inspection = template(
      'inspection-template',
      GeneratorPilotReadiness.inspectionSlug,
    );
    final maintenance = template(
      'maintenance-template',
      GeneratorPilotReadiness.maintenanceSlug,
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: tenantId,
      pilotEnabled: true,
      templates: [inspection, maintenance],
      revisionsByTemplateId: {
        inspection.id: [
          revision('inspection-r1', inspection.id, TemplateRevisionStatus.published),
        ],
        maintenance.id: [
          revision('maintenance-r1', maintenance.id, TemplateRevisionStatus.published),
        ],
      },
    );

    expect(readiness.fullyReady, isTrue);
    expect(readiness.canLaunchInspection, isTrue);
    expect(readiness.canLaunchMaintenance, isTrue);
    expect(readiness.inspection.statusLabel, 'Published revision 1');
    expect(readiness.blockers, isEmpty);
  });

  test('published packs remain data-ready when the build flag is off', () {
    final inspection = template(
      'inspection-template',
      GeneratorPilotReadiness.inspectionSlug,
    );
    final maintenance = template(
      'maintenance-template',
      GeneratorPilotReadiness.maintenanceSlug,
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: tenantId,
      pilotEnabled: false,
      templates: [inspection, maintenance],
      revisionsByTemplateId: {
        inspection.id: [
          revision('inspection-r1', inspection.id, TemplateRevisionStatus.published),
        ],
        maintenance.id: [
          revision('maintenance-r1', maintenance.id, TemplateRevisionStatus.published),
        ],
      },
    );

    expect(readiness.templateDataReady, isTrue);
    expect(readiness.fullyReady, isFalse);
    expect(readiness.canLaunchInspection, isFalse);
    expect(
      readiness.blockers,
      contains('This build does not enable VOLTCORE_GENERATOR_TEMPLATE_PILOT.'),
    );
  });

  test('missing active tenant blocks launch even when definitions are present', () {
    final inspection = template(
      'inspection-template',
      GeneratorPilotReadiness.inspectionSlug,
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: null,
      pilotEnabled: true,
      templates: [inspection],
      revisionsByTemplateId: {
        inspection.id: [
          revision('inspection-r1', inspection.id, TemplateRevisionStatus.published),
        ],
      },
    );

    expect(readiness.tenantConfigured, isFalse);
    expect(readiness.canLaunchInspection, isFalse);
    expect(readiness.blockers, contains('No active tenant is configured.'));
  });

  test('installed template without published revision is not pilot-ready', () {
    final inspection = template(
      'inspection-template',
      GeneratorPilotReadiness.inspectionSlug,
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: tenantId,
      pilotEnabled: true,
      templates: [inspection],
      revisionsByTemplateId: {
        inspection.id: [
          revision('inspection-r1', inspection.id, TemplateRevisionStatus.draft),
        ],
      },
    );

    expect(readiness.inspection.isReady, isFalse);
    expect(readiness.inspection.statusLabel, 'Installed • no published revision');
    expect(readiness.canLaunchInspection, isFalse);
  });

  test('duplicate active slugs fail closed instead of choosing one', () {
    final inspectionA = template(
      'inspection-a',
      GeneratorPilotReadiness.inspectionSlug,
    );
    final inspectionB = template(
      'inspection-b',
      GeneratorPilotReadiness.inspectionSlug,
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: tenantId,
      pilotEnabled: true,
      templates: [inspectionA, inspectionB],
      revisionsByTemplateId: const {},
    );

    expect(readiness.inspection.activeTemplateCount, 2);
    expect(readiness.inspection.isReady, isFalse);
    expect(
      readiness.inspection.statusLabel,
      '2 active templates use this slug',
    );
  });

  test('templates from another tenant do not satisfy the active-tenant gate', () {
    final inspection = template(
      'inspection-template',
      GeneratorPilotReadiness.inspectionSlug,
      tenant: 'tenant-b',
    );

    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: tenantId,
      pilotEnabled: true,
      templates: [inspection],
      revisionsByTemplateId: {
        inspection.id: [
          revision('inspection-r1', inspection.id, TemplateRevisionStatus.published),
        ],
      },
    );

    expect(readiness.inspection.activeTemplateCount, 0);
    expect(readiness.inspection.statusLabel, 'Not installed');
    expect(readiness.canLaunchInspection, isFalse);
  });
}
