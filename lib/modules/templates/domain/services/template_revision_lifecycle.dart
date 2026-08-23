import '../../../auth/domain/user_role.dart';
import '../entities/template_entities.dart';

typedef TemplateIdFactory = String Function();

/// Server-enforced template-management roles mirrored for client affordances.
///
/// This is never an authorization boundary: Supabase RLS and
/// `can_manage_tenant_work` remain authoritative for every write.
bool canManageTemplates(UserRole? role) =>
    role == UserRole.dispatcher ||
    role == UserRole.supervisor ||
    role == UserRole.admin;

/// Applies the append-only lifecycle used by the upcoming management UI.
///
/// A published revision is never edited. Cloning creates new definition IDs,
/// and publishing returns the prior live revision as an archive candidate so a
/// repository can persist the replacement atomically (archive first, then
/// publish to satisfy the single-published-revision database constraint).
class TemplateRevisionLifecycle {
  const TemplateRevisionLifecycle();

  FormTemplateDefinition cloneAsDraft({
    required FormTemplateDefinition source,
    required Iterable<FormTemplateRevision> existing,
    required TemplateIdFactory idFactory,
    required DateTime now,
  }) {
    final sectionIds = <String, String>{};
    for (final section in source.sections) {
      sectionIds[section.id] = idFactory();
    }
    final fieldIds = <String, String>{};
    for (final field in source.fields) {
      fieldIds[field.id] = idFactory();
    }
    final revisionId = idFactory();
    final nextRevisionNumber = existing
            .where((revision) => revision.templateId == source.template.id)
            .map((revision) => revision.revisionNumber)
            .fold<int>(
              0,
              (largest, number) => number > largest ? number : largest,
            ) +
        1;
    final revision = FormTemplateRevision(
      id: revisionId,
      tenantId: source.revision.tenantId,
      templateId: source.template.id,
      revisionNumber: nextRevisionNumber,
      status: TemplateRevisionStatus.draft,
      title: source.revision.title,
      instructions: source.revision.instructions,
      settings: Map<String, dynamic>.from(source.revision.settings),
      createdAt: now,
      updatedAt: now,
    );
    return FormTemplateDefinition(
      template: source.template,
      revision: revision,
      sections: source.sections
          .map(
            (section) => FormTemplateSection(
              id: sectionIds[section.id]!,
              tenantId: section.tenantId,
              revisionId: revisionId,
              key: section.key,
              title: section.title,
              description: section.description,
              position: section.position,
              visibilityRule: Map<String, dynamic>.from(section.visibilityRule),
            ),
          )
          .toList(growable: false),
      fields: source.fields
          .map(
            (field) => FormTemplateField(
              id: fieldIds[field.id]!,
              tenantId: field.tenantId,
              revisionId: revisionId,
              sectionId: sectionIds[field.sectionId]!,
              key: field.key,
              label: field.label,
              helpText: field.helpText,
              type: field.type,
              position: field.position,
              isRequired: field.isRequired,
              validation: Map<String, dynamic>.from(field.validation),
              visibilityRule: Map<String, dynamic>.from(field.visibilityRule),
              defaultValue: field.defaultValue,
            ),
          )
          .toList(growable: false),
      options: source.options
          .map(
            (option) => FormTemplateFieldOption(
              id: idFactory(),
              tenantId: option.tenantId,
              fieldId: fieldIds[option.fieldId]!,
              value: option.value,
              label: option.label,
              position: option.position,
            ),
          )
          .toList(growable: false),
    );
  }

  TemplatePublication publish({
    required FormTemplateRevision draft,
    required Iterable<FormTemplateRevision> existing,
    required DateTime now,
  }) {
    if (draft.status != TemplateRevisionStatus.draft) {
      throw StateError('Only a draft template revision can be published.');
    }
    final published = existing.where(
      (revision) =>
          revision.id != draft.id &&
          revision.templateId == draft.templateId &&
          revision.status == TemplateRevisionStatus.published,
    );
    if (published.length > 1) {
      throw StateError(
        'A template cannot have more than one published revision.',
      );
    }
    return TemplatePublication(
      archiveFirst: published.isEmpty
          ? null
          : _withStatus(
              published.single,
              TemplateRevisionStatus.archived,
              now,
            ),
      published: _withStatus(draft, TemplateRevisionStatus.published, now),
    );
  }

  FormTemplateRevision archive({
    required FormTemplateRevision revision,
    required DateTime now,
  }) {
    if (revision.status == TemplateRevisionStatus.published) {
      throw StateError(
        'Publish a replacement revision before archiving this one.',
      );
    }
    return _withStatus(revision, TemplateRevisionStatus.archived, now);
  }
}

class TemplatePublication {
  const TemplatePublication({required this.published, this.archiveFirst});

  final FormTemplateRevision published;
  final FormTemplateRevision? archiveFirst;
}

FormTemplateRevision _withStatus(
  FormTemplateRevision revision,
  TemplateRevisionStatus status,
  DateTime now,
) => FormTemplateRevision(
  id: revision.id,
  tenantId: revision.tenantId,
  templateId: revision.templateId,
  revisionNumber: revision.revisionNumber,
  status: status,
  title: revision.title,
  instructions: revision.instructions,
  settings: Map<String, dynamic>.from(revision.settings),
  publishedAt:
      status == TemplateRevisionStatus.published ? now : revision.publishedAt,
  createdAt: revision.createdAt,
  updatedAt: now,
);
