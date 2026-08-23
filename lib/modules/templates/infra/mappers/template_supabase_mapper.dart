import '../../domain/entities/template_entities.dart';

const kFormTemplatesTable = 'form_templates';
const kFormTemplateRevisionsTable = 'form_template_revisions';
const kFormTemplateSectionsTable = 'form_template_sections';
const kFormTemplateFieldsTable = 'form_template_fields';
const kFormTemplateFieldOptionsTable = 'form_template_field_options';
const kFormResponsesTable = 'form_responses';

FormTemplate formTemplateFromSupabaseJson(Map<String, dynamic> json) =>
    FormTemplate(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      assetType: json['asset_type'] as String? ?? 'generator',
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );

Map<String, dynamic> formTemplateToSupabaseJson(FormTemplate value) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'slug': value.slug,
  'name': value.name,
  'description': value.description,
  'asset_type': value.assetType,
  'is_archived': value.isArchived,
  'created_at': value.createdAt.toUtc().toIso8601String(),
  'updated_at': value.updatedAt.toUtc().toIso8601String(),
};

FormTemplateRevision formTemplateRevisionFromSupabaseJson(
  Map<String, dynamic> json,
) => FormTemplateRevision(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  templateId: json['template_id'] as String,
  revisionNumber: json['revision_number'] as int,
  status: TemplateRevisionStatus.values.byName(json['status'] as String),
  title: json['title'] as String,
  instructions: json['instructions'] as String? ?? '',
  settings: _map(json['settings']),
  publishedAt: _dateOrNull(json['published_at']),
  createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
);

Map<String, dynamic> formTemplateRevisionToSupabaseJson(
  FormTemplateRevision value,
) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'template_id': value.templateId,
  'revision_number': value.revisionNumber,
  'status': value.status.name,
  'title': value.title,
  'instructions': value.instructions,
  'settings': value.settings,
  'published_at': value.publishedAt?.toUtc().toIso8601String(),
  'created_at': value.createdAt.toUtc().toIso8601String(),
  'updated_at': value.updatedAt.toUtc().toIso8601String(),
};

FormTemplateSection formTemplateSectionFromSupabaseJson(
  Map<String, dynamic> json,
) => FormTemplateSection(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  revisionId: json['revision_id'] as String,
  key: json['section_key'] as String,
  title: json['title'] as String,
  description: json['description'] as String? ?? '',
  position: json['position'] as int,
  visibilityRule: _map(json['visibility_rule']),
);

Map<String, dynamic> formTemplateSectionToSupabaseJson(
  FormTemplateSection value,
) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'revision_id': value.revisionId,
  'section_key': value.key,
  'title': value.title,
  'description': value.description,
  'position': value.position,
  'visibility_rule': value.visibilityRule,
};

FormTemplateField formTemplateFieldFromSupabaseJson(Map<String, dynamic> json) =>
    FormTemplateField(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      revisionId: json['revision_id'] as String,
      sectionId: json['section_id'] as String,
      key: json['field_key'] as String,
      label: json['label'] as String,
      helpText: json['help_text'] as String? ?? '',
      type: TemplateFieldType.values.byName(json['field_type'] as String),
      position: json['position'] as int,
      isRequired: json['is_required'] as bool? ?? false,
      validation: _map(json['validation']),
      visibilityRule: _map(json['visibility_rule']),
      defaultValue: json['default_value'],
    );

Map<String, dynamic> formTemplateFieldToSupabaseJson(
  FormTemplateField value,
) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'revision_id': value.revisionId,
  'section_id': value.sectionId,
  'field_key': value.key,
  'label': value.label,
  'help_text': value.helpText,
  'field_type': value.type.name,
  'position': value.position,
  'is_required': value.isRequired,
  'validation': value.validation,
  'visibility_rule': value.visibilityRule,
  'default_value': value.defaultValue,
};

FormTemplateFieldOption formTemplateFieldOptionFromSupabaseJson(
  Map<String, dynamic> json,
) => FormTemplateFieldOption(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  fieldId: json['field_id'] as String,
  value: json['option_value'] as String,
  label: json['label'] as String,
  position: json['position'] as int,
);

Map<String, dynamic> formTemplateFieldOptionToSupabaseJson(
  FormTemplateFieldOption value,
) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'field_id': value.fieldId,
  'option_value': value.value,
  'label': value.label,
  'position': value.position,
};

FormResponse formResponseFromSupabaseJson(Map<String, dynamic> json) =>
    FormResponse(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      templateId: json['template_id'] as String,
      templateRevisionId: json['template_revision_id'] as String,
      status: _responseStatusFromDatabase(json['status'] as String),
      subjectType: json['subject_type'] as String,
      subjectId: json['subject_id'] as String?,
      customerId: json['customer_id'] as String?,
      siteId: json['site_id'] as String?,
      assetId: json['asset_id'] as String?,
      workOrderId: json['work_order_id'] as String?,
      inspectionId: json['inspection_id'] as String?,
      maintenanceRecordId: json['maintenance_record_id'] as String?,
      values: _map(json['values']),
      completedAt: _dateOrNull(json['completed_at']),
      completedByUserId: json['completed_by_user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );

Map<String, dynamic> formResponseToSupabaseJson(FormResponse value) => {
  'id': value.id,
  'tenant_id': value.tenantId,
  'template_id': value.templateId,
  'template_revision_id': value.templateRevisionId,
  'status': _responseStatusToDatabase(value.status),
  'subject_type': value.subjectType,
  'subject_id': value.subjectId,
  'customer_id': value.customerId,
  'site_id': value.siteId,
  'asset_id': value.assetId,
  'work_order_id': value.workOrderId,
  'inspection_id': value.inspectionId,
  'maintenance_record_id': value.maintenanceRecordId,
  'values': value.values,
  'completed_at': value.completedAt?.toUtc().toIso8601String(),
  'completed_by_user_id': value.completedByUserId,
  'created_at': value.createdAt.toUtc().toIso8601String(),
  'updated_at': value.updatedAt.toUtc().toIso8601String(),
};

Map<String, dynamic> _map(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : const <String, dynamic>{};

DateTime? _dateOrNull(Object? value) =>
    value is String ? DateTime.parse(value).toUtc() : null;

TemplateResponseStatus _responseStatusFromDatabase(String value) =>
    value == 'void'
        ? TemplateResponseStatus.voided
        : TemplateResponseStatus.values.byName(value);

String _responseStatusToDatabase(TemplateResponseStatus value) =>
    value == TemplateResponseStatus.voided ? 'void' : value.name;
