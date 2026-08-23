import 'package:flutter/foundation.dart';

enum TemplateRevisionStatus { draft, published, archived }

enum TemplateFieldType {
  text,
  number,
  date,
  select,
  boolean,
  checklist,
  reading,
  photo,
  signature,
}

enum TemplateResponseStatus { draft, completed, voided }

@immutable
class FormTemplate {
  const FormTemplate({
    required this.id,
    required this.tenantId,
    required this.slug,
    required this.name,
    required this.assetType,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.isArchived = false,
  });

  final String id;
  final String tenantId;
  final String slug;
  final String name;
  final String description;
  final String assetType;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class FormTemplateRevision {
  const FormTemplateRevision({
    required this.id,
    required this.tenantId,
    required this.templateId,
    required this.revisionNumber,
    required this.status,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.instructions = '',
    this.settings = const {},
    this.publishedAt,
  });

  final String id;
  final String tenantId;
  final String templateId;
  final int revisionNumber;
  final TemplateRevisionStatus status;
  final String title;
  final String instructions;
  final Map<String, dynamic> settings;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class FormTemplateSection {
  const FormTemplateSection({
    required this.id,
    required this.tenantId,
    required this.revisionId,
    required this.key,
    required this.title,
    required this.position,
    this.description = '',
    this.visibilityRule = const {},
  });

  final String id;
  final String tenantId;
  final String revisionId;
  final String key;
  final String title;
  final String description;
  final int position;
  final Map<String, dynamic> visibilityRule;
}

@immutable
class FormTemplateField {
  const FormTemplateField({
    required this.id,
    required this.tenantId,
    required this.revisionId,
    required this.sectionId,
    required this.key,
    required this.label,
    required this.type,
    required this.position,
    this.helpText = '',
    this.isRequired = false,
    this.validation = const {},
    this.visibilityRule = const {},
    this.defaultValue,
  });

  final String id;
  final String tenantId;
  final String revisionId;
  final String sectionId;
  final String key;
  final String label;
  final String helpText;
  final TemplateFieldType type;
  final int position;
  final bool isRequired;
  final Map<String, dynamic> validation;
  final Map<String, dynamic> visibilityRule;
  final Object? defaultValue;
}

@immutable
class FormTemplateFieldOption {
  const FormTemplateFieldOption({
    required this.id,
    required this.tenantId,
    required this.fieldId,
    required this.value,
    required this.label,
    required this.position,
  });

  final String id;
  final String tenantId;
  final String fieldId;
  final String value;
  final String label;
  final int position;
}

/// Immutable record of one technician's template-driven inspection or form.
@immutable
class FormResponse {
  const FormResponse({
    required this.id,
    required this.tenantId,
    required this.templateId,
    required this.templateRevisionId,
    required this.status,
    required this.subjectType,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.subjectId,
    this.customerId,
    this.siteId,
    this.assetId,
    this.workOrderId,
    this.inspectionId,
    this.maintenanceRecordId,
    this.completedAt,
    this.completedByUserId,
  });

  final String id;
  final String tenantId;
  final String templateId;
  final String templateRevisionId;
  final TemplateResponseStatus status;
  final String subjectType;
  final String? subjectId;
  final String? customerId;
  final String? siteId;
  final String? assetId;
  final String? workOrderId;
  final String? inspectionId;
  final String? maintenanceRecordId;
  final Map<String, dynamic> values;
  final DateTime? completedAt;
  final String? completedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComplete => status == TemplateResponseStatus.completed;
}
