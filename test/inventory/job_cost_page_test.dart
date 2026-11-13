import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/job_cost.dart';
import 'package:voltcore/modules/inventory/domain/job_needs.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/job_needs_providers.dart';
import 'package:voltcore/modules/inventory/presenter/movement_providers.dart';
import 'package:voltcore/modules/inventory/presenter/pages/job_needs_page.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

class _Repo extends InventoryRepository {
  _Repo() : super(tenantId: () => null);
}

final _t = DateTime.utc(2026);
final _part = CatalogPart(
    id: 'p1',
    partNumber: 'LF3000',
    name: 'Oil filter',
    createdAt: _t,
    updatedAt: _t);

List<JobNeeds> _needs() => computeJobNeeds([
      JobNeedsInput(
        type: MaterialOwnerType.inspection,
        id: 'a',
        title: '12 Main St',
        subtitle: 'Inspection',
        items: [
          const MaterialItem(
              id: 'i1',
              slot: MaterialSlot.oilFilter,
              partNumber: 'LF3000',
              quantity: 2,
              needsReplacement: true),
        ],
      ),
    ], [
      _part
    ], [
      InventoryMovement(
          id: 'm',
          partId: 'p1',
          qtyDelta: 5,
          reason: MovementReason.receive,
          at: _t),
    ]);

final _costs = {
  'inspection:a': const JobCost([
    JobPartCost(partId: 'p1', qty: 2, unitCents: 61725),
    JobPartCost(partId: 'p2', qty: 1),
  ]),
};

Widget _host({required bool admin}) => ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(_Repo()),
        canReserveStockProvider.overrideWithValue(true),
        canSeeJobCostProvider.overrideWithValue(admin),
        jobNeedsProvider.overrideWith((ref) async => _needs()),
        jobCostsProvider.overrideWith((ref) async => _costs),
      ],
      child: const MaterialApp(home: JobNeedsPage()),
    );

void main() {
  testWidgets('an admin sees the parts cost and unpriced count', (t) async {
    await t.pumpWidget(_host(admin: true));
    await t.pump();
    await t.pump();
    expect(find.text('Parts cost \$1,234.50 · 1 part not priced'),
        findsOneWidget);
  });

  testWidgets('a non-admin never sees a cost', (t) async {
    await t.pumpWidget(_host(admin: false));
    await t.pump();
    await t.pump();
    expect(find.textContaining('Parts cost'), findsNothing);
  });
}
