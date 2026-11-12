import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/job_needs.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/job_needs_providers.dart';
import 'package:voltcore/modules/inventory/presenter/pages/job_needs_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/shortages_page.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

class _Repo extends InventoryRepository {
  _Repo() : super(tenantId: () => null);
  final calls = <String>[];

  @override
  Future<void> reserveForJob(String jobRef, String partId, int qty, {String note = ''}) async =>
      calls.add('reserve $jobRef $partId $qty');
}

final _t = DateTime.utc(2026);
final _part = CatalogPart(id: 'p1', partNumber: 'LF3000', name: 'Oil filter', createdAt: _t, updatedAt: _t);

List<JobNeeds> _needs() => computeJobNeeds([
      JobNeedsInput(
        type: MaterialOwnerType.inspection,
        id: 'a',
        title: '12 Main St',
        subtitle: 'Inspection',
        items: [
          const MaterialItem(id: 'i1', slot: MaterialSlot.oilFilter, partNumber: 'LF3000', quantity: 2, needsReplacement: true),
          const MaterialItem(id: 'i2', slot: MaterialSlot.airFilter, partNumber: 'NOPE', needsReplacement: true),
        ],
      ),
    ], [
      _part
    ], [
      InventoryMovement(id: 'm', partId: 'p1', qtyDelta: 5, reason: MovementReason.receive, at: _t),
    ]);

Widget _host(Widget page, _Repo repo, {required bool canAct}) => ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        canReserveStockProvider.overrideWithValue(canAct),
        jobNeedsProvider.overrideWith((ref) async => _needs()),
        shortagesProvider.overrideWith((ref) async => computeShortages(_needs())),
        lowStockProvider.overrideWith((ref) async => const <StockLevel>[]),
      ],
      child: MaterialApp(home: page),
    );

void _quiet() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
}

void main() {
  testWidgets('shows each need with its status; admin can reserve', (t) async {
    _quiet();
    final repo = _Repo();
    await t.pumpWidget(_host(const JobNeedsPage(), repo, canAct: true));
    await t.pump();
    await t.pump();

    expect(find.text('12 Main St'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.text('Not in catalog'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('actions-i1')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Reserve'));
    await t.pump();
    expect(repo.calls, ['reserve inspection:a p1 2']);
  });

  testWidgets('a technician sees the needs but no actions', (t) async {
    _quiet();
    await t.pumpWidget(_host(const JobNeedsPage(), _Repo(), canAct: false));
    await t.pump();
    await t.pump();
    expect(find.text('In stock'), findsOneWidget);
    expect(find.byKey(const ValueKey('actions-i1')), findsNothing);
  });

  testWidgets('shortages lists parts missing from the catalog', (t) async {
    _quiet();
    await t.pumpWidget(_host(const ShortagesPage(), _Repo(), canAct: false));
    await t.pump();
    await t.pump();
    expect(find.text('NOPE'), findsOneWidget);
    expect(find.text('Order 1'), findsOneWidget);
  });
}
