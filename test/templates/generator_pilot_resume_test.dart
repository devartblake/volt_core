import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/domain/services/generator_pilot_resume.dart';

void main() {
  final now = DateTime.utc(2026, 9, 3, 18);

  FormTemplate template({
    required String id,
    required String tenantId,
    required String slug,
    bool archived = false,
  }) {
    return FormTemplate(
      id: id,
      tenantId: tenantId,
      slug: slug,
      name: slug,
      assetType: 'generator',
      isArchived: archived,
      createdAt: now,
      updatedAt: now,
    );
  }

  FormResponse response({
    required String id,
    required String tenantId,
    required String templateId,
    required TemplateResponseStatus status,
    required DateTime updatedAt,
  }) {
    return FormResponse(
      id: id,
      tenantId: tenantId,
      templateId: templateId,
      templateRevisionId: 'revision-$templateId',
      status: status,
      subjectType: 'asset',
      values: const {},
      createdAt: updatedAt.subtract(const Duration(minutes: 5)),
      updatedAt: updatedAt,
    );
  }

  test('returns only active-tenant draft generator pilot responses', () {
    final templates = [
      template(
        id: 'inspection-template',
        tenantId: 'tenant-a',
        slug: 'generator-inspection',
      ),
      template(
        id: 'maintenance-template',
        tenantId: 'tenant-a',
        slug: 'generator-maintenance',
      ),
      template(
        id: 'other-template',
        tenantId: 'tenant-a',
        slug: 'ats-inspection',
      ),
      template(
        id: 'foreign-template',
        tenantId: 'tenant-b',
        slug: 'generator-inspection',
      ),
    ];
    final responses = [
      response(
        id: 'inspection-draft',
        tenantId: 'tenant-a',
        templateId: 'inspection-template',
        status: TemplateResponseStatus.draft,
        updatedAt: now,
      ),
      response(
        id: 'maintenance-draft',
        tenantId: 'tenant-a',
        templateId: 'maintenance-template',
        status: TemplateResponseStatus.draft,
        updatedAt: now.add(const Duration(minutes: 2)),
      ),
      response(
        id: 'completed',
        tenantId: 'tenant-a',
        templateId: 'inspection-template',
        status: TemplateResponseStatus.completed,
        updatedAt: now.add(const Duration(minutes: 3)),
      ),
      response(
        id: 'other-draft',
        tenantId: 'tenant-a',
        templateId: 'other-template',
        status: TemplateResponseStatus.draft,
        updatedAt: now,
      ),
      response(
        id: 'foreign-draft',
        tenantId: 'tenant-b',
        templateId: 'foreign-template',
        status: TemplateResponseStatus.draft,
        updatedAt: now,
      ),
    ];

    final items = GeneratorPilotResumeService.drafts(
      tenantId: 'tenant-a',
      responses: responses,
      templates: templates,
    );

    expect(
      items.map((item) => item.response.id),
      ['maintenance-draft', 'inspection-draft'],
    );
  });

  test('archived pilot templates are not offered for resume', () {
    final items = GeneratorPilotResumeService.drafts(
      tenantId: 'tenant-a',
      templates: [
        template(
          id: 'inspection-template',
          tenantId: 'tenant-a',
          slug: 'generator-inspection',
          archived: true,
        ),
      ],
      responses: [
        response(
          id: 'draft',
          tenantId: 'tenant-a',
          templateId: 'inspection-template',
          status: TemplateResponseStatus.draft,
          updatedAt: now,
        ),
      ],
    );

    expect(items, isEmpty);
  });

  test('empty tenant fails closed', () {
    final items = GeneratorPilotResumeService.drafts(
      tenantId: '',
      responses: const [],
      templates: const [],
    );

    expect(items, isEmpty);
  });
}
