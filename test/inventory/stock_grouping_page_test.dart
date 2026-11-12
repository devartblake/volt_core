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

final _t = DateTime.utc(2026, 1, 1);

CatalogPart _p(String id, String n, String mfr) => CatalogPart(
    id: id, partNumber: n, manufacturer: mfr, createdAt: _t, updatedAt: _t);

class _Repo extends InventoryRepository {
  @override
  Future<List<InventoryLocation>> locations({bool includeInactive = false}) async =>
      [InventoryLocation.main()];

  _Repo(this._parts) : super(tenantId: () => null);
  final List<CatalogPart> _parts;

  @override
  Future<List<CatalogPart>> parts() async => _parts;
  @override
  Future<List<InventoryMovement>> movements({String? partId}) async => [
        for (final p in _parts)
          InventoryMovement(
              id: 'm${p.id}', partId: p.id, qtyDelta: 5,
              reason: MovementReason.receive, at: _t),
      ];
  @override
  Future<List<StockLevel>> stock() async =>
      computeStock(_parts, await movements());
  @override
  Future<int> refreshFromCloud() async => 0;
}

class _Pricing extends PricingRepository {
  _Pricing(this._prices) : super(tenantId: () => null);
  final List<PartPrice> _prices;
  @override
  Future<List<Vendor>> vendors() async => [
        Vendor(id: 'v', name: 'Graybar', createdAt: _t, updatedAt: _t),
      ];
  @override
  Future<List<PartPrice>> prices({String? partId}) async => [
        for (final p in _prices)
          if (partId == null || p.partId == partId) p,
      ];
  @override
  Future<int> refreshFromCloud() async => 0;
}

Widget _host({required bool admin, List<PartPrice> prices = const []}) =>
    ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(_Repo([
          _p('1', 'BF1', 'Baldwin'),
          _p('2', 'P55', 'Donaldson'),
          _p('3', 'P56', 'donaldson'),
          _p('4', 'ZZ', ''),
        ])),
        pricingRepositoryProvider.overrideWithValue(_Pricing(prices)),
        canManageInventoryProvider.overrideWithValue(admin),
      ],
      child: const MaterialApp(home: StockPage()),
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

  Future<void> open(WidgetTester t, Widget w) async {
    await t.pumpWidget(w);
    await t.pump();
    await t.pump();
  }

  testWidgets('stock is grouped by manufacturer by default', (t) async {
    ignoreOverflow();
    await open(t, _host(admin: false));

    expect(find.text('BALDWIN · 1'), findsOneWidget);
    // "Donaldson" and "donaldson" share a heading.
    expect(find.text('DONALDSON · 2'), findsOneWidget);
    await t.scrollUntilVisible(find.text('NO MANUFACTURER · 1'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('NO MANUFACTURER · 1'), findsOneWidget);
  });

  testWidgets('picking a manufacturer narrows the list', (t) async {
    ignoreOverflow();
    await open(t, _host(admin: false));

    await t.tap(find.byKey(const Key('maker_Baldwin')));
    await t.pump();
    expect(find.text('BF1'), findsOneWidget);
    expect(find.text('P55'), findsNothing);

    await t.tap(find.text('All makers'));
    await t.pump();
    expect(find.text('P55'), findsOneWidget);
  });

  testWidgets('grouping can be turned off', (t) async {
    ignoreOverflow();
    await open(t, _host(admin: false));

    await t.tap(find.descendant(
        of: find.byKey(const Key('stock_group')), matching: find.text('None')));
    await t.pump();
    expect(find.text('BALDWIN · 1'), findsNothing);
    expect(find.text('BF1'), findsOneWidget);
  });

  testWidgets('admins see the last price paid and the shelf value', (t) async {
    ignoreOverflow();
    await open(
      t,
      _host(admin: true, prices: [
        PartPrice(
            id: 'x', partId: '1', vendorId: 'v', unitCents: 2450,
            pricedAt: _t, createdAt: _t),
      ]),
    );
    expect(find.textContaining(r'last $24.50'), findsOneWidget);
    expect(find.byKey(const Key('stock_value')), findsOneWidget);
    expect(find.textContaining(r'$122.50'), findsOneWidget); // 5 x 24.50
  });

  testWidgets('technicians see no prices', (t) async {
    ignoreOverflow();
    await open(
      t,
      _host(admin: false, prices: [
        PartPrice(
            id: 'x', partId: '1', vendorId: 'v', unitCents: 2450,
            pricedAt: _t, createdAt: _t),
      ]),
    );
    expect(find.textContaining(r'$24.50'), findsNothing);
    expect(find.byKey(const Key('stock_value')), findsNothing);
  });

  testWidgets('an admin can edit a part and add a price from its page', (t) async {
    ignoreOverflow();
    await open(t, _host(admin: true));

    await t.tap(find.text('BF1'));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('edit_part')), findsOneWidget);
    expect(find.byKey(const Key('add_price')), findsOneWidget);
  });

  testWidgets('a technician sees neither', (t) async {
    ignoreOverflow();
    await open(t, _host(admin: false));

    await t.tap(find.text('BF1'));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('edit_part')), findsNothing);
    expect(find.byKey(const Key('add_price')), findsNothing);
  });
}
