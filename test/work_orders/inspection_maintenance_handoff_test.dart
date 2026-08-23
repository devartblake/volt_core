import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/customers/customer_site_repository.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/work_orders/application/inspection_maintenance_handoff.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/providers/equipment_providers.dart';

void main() {
  test('creates a scheduled, site-linked maintenance draft from an inspection', () {
    final inspection = InspectionEntity(
      id: 'inspection-1',
      createdAt: DateTime.utc(2026, 8, 20),
      updatedAt: DateTime.utc(2026, 8, 20),
      serviceDate: DateTime.utc(2026, 8, 20),
      technicianSigDate: DateTime.utc(2026, 8, 20),
      customerSigDate: DateTime.utc(2026, 8, 20),
      siteCode: 'Q844',
      siteGrade: 'Red',
      generatorSerial: 'GEN-42',
      deficienciesDocumented: true,
      notes: 'Replace the fuel line.',
    );
    const site = SiteRecord(
      id: 'site-1',
      siteCode: 'Q844',
      address: '952 Flushing Ave',
      customerId: 'customer-1',
    );
    const asset = Equipment(
      id: 'inspection-asset',
      registryId: 'asset-1',
      name: 'Generator',
      make: 'Cummins',
      model: 'C100',
      serialNumber: 'GEN-42',
      voltage: '208V',
      location: 'Basement',
      siteId: 'site-1',
    );

    final draft = InspectionMaintenanceHandoff.draftFor(
      inspection,
      directory: const CustomerSiteDirectory(sites: [site]),
      equipment: const [asset],
      scheduledFor: DateTime.utc(2026, 8, 25),
    );

    expect(draft.title, contains('Q844'));
    expect(draft.priority, WorkOrderPriority.high);
    expect(draft.customerId, 'customer-1');
    expect(draft.siteId, 'site-1');
    expect(draft.assetId, 'asset-1');
    expect(draft.description, contains('inspection-1'));
    expect(draft.description, contains('Replace the fuel line.'));
  });
}
