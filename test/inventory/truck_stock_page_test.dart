import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/vendor.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/infra/pricing_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/pages/stock_page.dart';
import 'package:voltcore/modules/inventory/presenter/widgets/location_sheets.dart';

final _t = DateTime.utc(2026, 1, 1);

class _NoPricing extends PricingRepository {
  _NoPricing() : super(tenantId: () => null);
  @override
  Future<List<Vendor>> vendors() async => const [];
  @override
  Future<List<PartPrice>> prices({String? partId}) async => const [];
  @override
  Future<int> refreshFromCloud() async => 0;
}

class _Repo extends InventoryRepository {
  _Repo() : super(tenantId: () => null);

  final truck = InventoryLocation(
      id: 'truck', name: 'Truck A', updatedAt: _t);
  final part =
      CatalogPart(id: 'p', partNumber: 'LF3000', createdAt: _t, updatedAt: _t);
  late final List<InventoryMovement> moves = [
    InventoryMovement(
        id: '1',
        partId: 'p',
        qtyDelta: 10,
        reason: MovementReason.receive,
        at: _t),
    InventoryMovement(
        id: '2',
        partId: 'p',
        qtyDelta: -3,
        reason: MovementReason.transfer,
        at: _t),
    InventoryMovement(
        id: '3',
        partId: 'p',
        qtyDelta: 3,
        reason: MovementReason.transfer,
        at: _t,
        locationId: 'truck'),
  ];
  final transfers = <(String, String, int)>[];

  @override
  Future<List<CatalogPart>> parts() async => [part];
  @override
  Future<List<InventoryMovement>> movements({String? partId}) async => moves;
  @override
  Future<List<StockLevel>> stock() async => computeStock([part], moves);
  @override
  Future<List<StockLevel>> stockAt(String id) async =>
      computeStockAt([part], moves, id);
  @override
  Future<List<InventoryLocation>> locations(
          {bool includeInactive = false}) async =>
      [InventoryLocation.main(), truck];
  @override
  Future<int> refreshFromCloud() async => 0;
  @override
  Future<void> transfer({
    required String partId,
    required String fromId,
    required String toId,
    required int qty,
    String note = '',
  }) async {
    final have = onHandAt(moves, partId, fromId);
    if (qty > have) throw ArgumentError('Only $have on hand at the source.');
    transfers.add((fromId, toId, qty));
  }
}

Widget _host(Widget home, _Repo repo, {bool admin = false, bool reserve = true}) =>
    ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        pricingRepositoryProvider.overrideWithValue(_NoPricing()),
        canManageInventoryProvider.overrideWithValue(admin),
        canReserveStockProvider.overrideWithValue(reserve),
      ],
      child: MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  void ignoreOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  for (final (name, size) in [
    ('phone', const Size(390, 900)),
    ('tablet', const Size(900, 1200)),
  ]) {
    testWidgets('location chips switch the stock shown ($name)', (t) async {
      ignoreOverflow();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_host(const StockPage(), _Repo(), admin: true));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const Key('location_chips')), findsOneWidget);
      expect(find.byKey(const Key('manage_locations')), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await t.tap(find.byKey(const Key('location_chip_truck')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('3'), findsOneWidget);

      await t.tap(find.byKey(const Key('location_chip_main')));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('7'), findsOneWidget);
    });
  }

  testWidgets('transfer sheet blocks more than is on hand, then moves stock',
      (t) async {
    ignoreOverflow();
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = _Repo();
    await t.pumpWidget(_host(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showTransferSheet(context, ref, part: repo.part),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      repo,
    ));
    await t.tap(find.text('open'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Transfer stock'), findsOneWidget);

    // To: Truck A
    await t.tap(find.byKey(const Key('transfer_to')));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await t.tap(find.text('Truck A').last);
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }

    await t.enterText(find.byKey(const Key('transfer_qty')), '9');
    await t.tap(find.byKey(const Key('save_transfer')));
    await t.pump();
    expect(find.text('Only 7 on hand at the source.'), findsOneWidget);
    expect(repo.transfers, isEmpty);

    await t.enterText(find.byKey(const Key('transfer_qty')), '4');
    await t.tap(find.byKey(const Key('save_transfer')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(repo.transfers.single, (kMainLocationId, 'truck', 4));
  });
}
