import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/templates/domain/entities/template_entities.dart';
import 'package:voltcore/modules/templates/infra/mappers/template_supabase_mapper.dart';

void main() {
  group('Phase 3 template mapper', () {
    test('maps a structured form response without losing revision provenance', () {
      final response = formResponseFromSupabaseJson({
        'id': 'response-1',
        'tenant_id': 'tenant-1',
        'template_id': 'template-1',
        'template_revision_id': 'revision-2',
        'status': 'completed',
        'subject_type': 'asset',
        'asset_id': 'asset-1',
        'values': {'load_kw': 250, 'fuel_ok': true},
        'completed_at': '2026-08-23T12:00:00.000Z',
        'completed_by_user_id': 'user-1',
        'created_at': '2026-08-23T11:00:00.000Z',
        'updated_at': '2026-08-23T12:00:00.000Z',
      });

      expect(response.status, TemplateResponseStatus.completed);
      expect(response.templateRevisionId, 'revision-2');
      expect(response.values['load_kw'], 250);
      expect(formResponseToSupabaseJson(response)['asset_id'], 'asset-1');
    });

    test('maps the database void state to the Dart-safe enum name', () {
      final response = formResponseFromSupabaseJson({
        'id': 'response-void',
        'tenant_id': 'tenant-1',
        'template_id': 'template-1',
        'template_revision_id': 'revision-1',
        'status': 'void',
        'subject_type': 'asset',
        'values': <String, dynamic>{},
        'created_at': '2026-08-23T11:00:00.000Z',
        'updated_at': '2026-08-23T11:00:00.000Z',
      });

      expect(response.status, TemplateResponseStatus.voided);
      expect(formResponseToSupabaseJson(response)['status'], 'void');
    });

    test('maps field validation and selection metadata', () {
      final field = formTemplateFieldFromSupabaseJson({
        'id': 'field-1',
        'tenant_id': 'tenant-1',
        'revision_id': 'revision-1',
        'section_id': 'section-1',
        'field_key': 'site_grade',
        'label': 'Site grade',
        'field_type': 'select',
        'position': 1,
        'is_required': true,
        'validation': {'allowed': ['green', 'amber', 'red']},
        'visibility_rule': {},
      });

      expect(field.type, TemplateFieldType.select);
      expect(field.isRequired, isTrue);
      expect(field.validation['allowed'], ['green', 'amber', 'red']);
    });

    test('keeps all Phase 3 table names stable for sync clients', () {
      expect(kFormTemplatesTable, 'form_templates');
      expect(kFormTemplateRevisionsTable, 'form_template_revisions');
      expect(kFormResponsesTable, 'form_responses');
    });
  });
}
