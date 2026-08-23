import '../../customers/customer_site_repository.dart';
import '../../inspections/domain/entities/inspection_entity.dart';
import '../../../providers/equipment_providers.dart';
import '../domain/entities/work_order_entity.dart';

/// The prefilled payload for maintenance work raised from a completed
/// inspection. Keeping the mapping in one place makes this handoff reusable
/// from inspection details, lists, and future deficiency workflows.
class InspectionMaintenanceHandoff {
  const InspectionMaintenanceHandoff._();

  static WorkOrderHandoffDraft draftFor(
    InspectionEntity inspection, {
    required CustomerSiteDirectory directory,
    required List<Equipment> equipment,
    required DateTime scheduledFor,
  }) {
    final site = _siteFor(inspection, directory);
    final asset = _assetFor(inspection, equipment, site?.id);
    final grade = inspection.siteGrade.trim();
    final source = <String>[
      'Created from inspection ${inspection.id}.',
      if (grade.isNotEmpty) 'Inspection grade: $grade.',
      if (inspection.deficienciesDocumented) 'Deficiencies were documented.',
      if (inspection.notes.trim().isNotEmpty) 'Inspection notes: ${inspection.notes.trim()}',
    ].join('\n');

    return WorkOrderHandoffDraft(
      title: 'Maintenance follow-up — ${_siteLabel(inspection)}',
      priority: _priorityFor(inspection.siteGrade, inspection.deficienciesDocumented),
      customerId: site?.customerId,
      siteId: site?.id,
      assetId: asset?.registryId ?? asset?.id,
      scheduledFor: scheduledFor,
      description: source,
    );
  }

  static SiteRecord? _siteFor(
    InspectionEntity inspection,
    CustomerSiteDirectory directory,
  ) {
    final code = inspection.siteCode.trim().toLowerCase();
    final address = inspection.address.trim().toLowerCase();
    for (final site in directory.sites) {
      if (code.isNotEmpty && site.siteCode.trim().toLowerCase() == code) {
        return site;
      }
      if (address.isNotEmpty && site.address.trim().toLowerCase() == address) {
        return site;
      }
    }
    return null;
  }

  static Equipment? _assetFor(
    InspectionEntity inspection,
    List<Equipment> equipment,
    String? siteId,
  ) {
    final serial = inspection.generatorSerial.trim().toLowerCase();
    for (final asset in equipment) {
      if (siteId != null && asset.siteId != siteId) continue;
      if (serial.isNotEmpty && asset.serialNumber.trim().toLowerCase() == serial) {
        return asset;
      }
    }
    return null;
  }

  static WorkOrderPriority _priorityFor(String grade, bool deficiencies) {
    if (deficiencies || grade.trim().toLowerCase() == 'red') {
      return WorkOrderPriority.high;
    }
    if (grade.trim().toLowerCase() == 'amber') {
      return WorkOrderPriority.normal;
    }
    return WorkOrderPriority.low;
  }

  static String _siteLabel(InspectionEntity inspection) {
    final siteCode = inspection.siteCode.trim();
    if (siteCode.isNotEmpty) return siteCode;
    final address = inspection.address.trim();
    return address.isEmpty ? 'inspection site' : address;
  }
}

class WorkOrderHandoffDraft {
  const WorkOrderHandoffDraft({
    required this.title,
    required this.priority,
    required this.scheduledFor,
    required this.description,
    this.customerId,
    this.siteId,
    this.assetId,
  });

  final String title;
  final WorkOrderPriority priority;
  final String? customerId;
  final String? siteId;
  final String? assetId;
  final DateTime scheduledFor;
  final String description;
}
