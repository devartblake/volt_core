import '../entities/template_entities.dart';

/// Readiness for one generator template used by the controlled Phase 3 pilot.
class GeneratorPilotTemplateReadiness {
  const GeneratorPilotTemplateReadiness({
    required this.slug,
    required this.label,
    required this.activeTemplateCount,
    required this.publishedRevisionCount,
    this.template,
    this.publishedRevision,
  });

  final String slug;
  final String label;
  final int activeTemplateCount;
  final int publishedRevisionCount;
  final FormTemplate? template;
  final FormTemplateRevision? publishedRevision;

  bool get isReady =>
      activeTemplateCount == 1 &&
      publishedRevisionCount == 1 &&
      template != null &&
      publishedRevision != null;

  String get statusLabel {
    if (activeTemplateCount == 0) return 'Not installed';
    if (activeTemplateCount > 1) {
      return '$activeTemplateCount active templates use this slug';
    }
    if (publishedRevisionCount == 0) return 'Installed • no published revision';
    if (publishedRevisionCount > 1) {
      return '$publishedRevisionCount published revisions found';
    }
    return 'Published revision ${publishedRevision!.revisionNumber}';
  }
}

/// Pure evaluation of the prerequisites for starting the generator template
/// pilot. Keeping this separate from the page makes the rollout gate testable
/// and prevents the UI from silently launching against an ambiguous template.
class GeneratorPilotReadiness {
  const GeneratorPilotReadiness({
    required this.tenantId,
    required this.pilotEnabled,
    required this.inspection,
    required this.maintenance,
  });

  static const inspectionSlug = 'generator-inspection';
  static const maintenanceSlug = 'generator-maintenance';

  final String? tenantId;
  final bool pilotEnabled;
  final GeneratorPilotTemplateReadiness inspection;
  final GeneratorPilotTemplateReadiness maintenance;

  bool get tenantConfigured => tenantId != null && tenantId!.trim().isNotEmpty;

  bool get templateDataReady =>
      tenantConfigured && inspection.isReady && maintenance.isReady;

  bool get canLaunchInspection =>
      pilotEnabled && tenantConfigured && inspection.isReady;

  bool get canLaunchMaintenance =>
      pilotEnabled && tenantConfigured && maintenance.isReady;

  bool get fullyReady =>
      pilotEnabled && tenantConfigured && inspection.isReady && maintenance.isReady;

  List<String> get blockers {
    final items = <String>[];
    if (!tenantConfigured) items.add('No active tenant is configured.');
    if (!inspection.isReady) {
      items.add('Generator Inspection is not uniquely published.');
    }
    if (!maintenance.isReady) {
      items.add('Generator Maintenance is not uniquely published.');
    }
    if (!pilotEnabled) {
      items.add(
        'This build does not enable VOLTCORE_GENERATOR_TEMPLATE_PILOT.',
      );
    }
    return List.unmodifiable(items);
  }

  static GeneratorPilotReadiness evaluate({
    required String? tenantId,
    required bool pilotEnabled,
    required Iterable<FormTemplate> templates,
    required Map<String, List<FormTemplateRevision>> revisionsByTemplateId,
  }) {
    final normalizedTenantId = tenantId?.trim();

    GeneratorPilotTemplateReadiness evaluateTemplate({
      required String slug,
      required String label,
    }) {
      final active = templates
          .where(
            (template) =>
                template.slug == slug &&
                !template.isArchived &&
                (normalizedTenantId == null ||
                    normalizedTenantId.isEmpty ||
                    template.tenantId == normalizedTenantId),
          )
          .toList(growable: false);

      if (active.length != 1) {
        return GeneratorPilotTemplateReadiness(
          slug: slug,
          label: label,
          activeTemplateCount: active.length,
          publishedRevisionCount: 0,
        );
      }

      final template = active.single;
      final published = (revisionsByTemplateId[template.id] ?? const [])
          .where((revision) => revision.status == TemplateRevisionStatus.published)
          .toList(growable: false);

      return GeneratorPilotTemplateReadiness(
        slug: slug,
        label: label,
        activeTemplateCount: 1,
        publishedRevisionCount: published.length,
        template: template,
        publishedRevision: published.length == 1 ? published.single : null,
      );
    }

    return GeneratorPilotReadiness(
      tenantId: normalizedTenantId,
      pilotEnabled: pilotEnabled,
      inspection: evaluateTemplate(
        slug: inspectionSlug,
        label: 'Generator Inspection',
      ),
      maintenance: evaluateTemplate(
        slug: maintenanceSlug,
        label: 'Generator Maintenance',
      ),
    );
  }
}
