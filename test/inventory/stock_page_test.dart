import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/vendor.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/infra/pricing_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/pages/parts_catalog_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/stock_page.dart';

/// No vendors or prices; keeps Hive out of the page tests.
class _NoPricing extends PricingRepository {
  _NoPricing() : super(tenantId: () => null);
  @override
  Future<List<Vendor>> vendors() async => const [];
  @override
  Future<List<PartPrice>> prices({String? partId}) async => const [];
  @override
  Future<int> refreshFromCloud() async => 0;
}

/// In-memory repository: Hive writes never complete on the test's fake clock.
class _MemRepo extends InventoryRepository {
  @override
  Future<List<InventoryLocation>> locations({bool includeInactive = false}) async =>
      [InventoryLocation.main()];

  _MemRepo(this._parts, this._moves) : super(tenantId: () => null);

  final List<CatalogPart> _parts;
  final List<InventoryMovement> _moves;
  var _n = 0;

  @override
  Future<List<CatalogPart>> parts() async => List.of(_parts);

  @override
  Future<List<InventoryMovement>> movements({String? partId}) async => [
        for (final m in _moves)
          if (partId == null || m.partId == partId) m,
      ];

  @override
  Future<List<StockLevel>> stock() async => computeStock(_parts, _moves);

  @override
  Future<int> refreshFromCloud() async => 0;

  @override
  Future<CatalogPart> savePart(CatalogPart part) async {
    for (final o in _parts) {
      if (o.id != part.id && partKey(o.partNumber) == partKey(part.partNumber)) {
        throw DuplicatePartException(o);
      }
    }
    _parts.removeWhere((p) => p.id == part.id);
    _parts.add(part);
    return part;
  }

  @override
  Future<InventoryMovement?> record({
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async {
    final m = InventoryMovement(
        id: 'm${_n++}', partId: partId, qtyDelta: qty, reason: reason, at: DateTime.now(), note: note);
    _moves.add(m);
    return m;
  }
}

final _t = DateTime.utc(2026, 1, 1);
CatalogPart _p(String id, String n, {String name = '', int min = 0}) => CatalogPart(
    id: id, partNumber: n, name: name, minStock: min, createdAt: _t, updatedAt: _t);
InventoryMovement _m(String id, String part, int q) => InventoryMovement(
    id: id, partId: part, qtyDelta: q, reason: MovementReason.receive, at: _t);

Widget _host(Widget page, _MemRepo repo, {required bool admin}) => ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        pricingRepositoryProvider.overrideWithValue(_NoPricing()),
        canManageInventoryProvider.overrideWithValue(admin),
      ],
      child: MaterialApp(home: page),
    );

void main() {
  _MemRepo repo() => _MemRepo([
        _p('1', 'LF3000', name: 'Oil filter', min: 5),
        _p('2', 'AF25550', name: 'Air filter'),
        _p('3', 'BAT-31'),
      ], [
        _m('a', '1', 2), // low
        _m('b', '2', 20), // ok
      ]);

  void ignoreOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  group('role gate', () {
    test('only admins manage inventory', () {
      expect(canManageInventory(UserRole.admin), isTrue);
      for (final r in [UserRole.tech, UserRole.supervisor, UserRole.dispatcher, null]) {
        expect(canManageInventory(r), isFalse);
      }
    });
  });

  group('StockPage', () {
    testWidgets('shows parts, status and counts; tech has no receive button', (t) async {
      ignoreOverflow();
      await t.pumpWidget(_host(const StockPage(), repo(), admin: false));
      await t.pump();
      await t.pump();

      expect(find.text('LF3000'), findsOneWidget);
      expect(find.text('AF25550'), findsOneWidget);
      expect(find.text('Low'), findsWidgets);
      expect(find.byKey(const Key('receive_stock')), findsNothing);
    });

    testWidgets('filters to out of stock', (t) async {
      ignoreOverflow();
      await t.pumpWidget(_host(const StockPage(), repo(), admin: false));
      await t.pump();
      await t.pump();

      await t.tap(find.widgetWithText(ChoiceChip, 'Out of stock'));
      await t.pump();
      expect(find.text('BAT-31'), findsOneWidget);
      expect(find.text('LF3000'), findsNothing);
    });

    testWidgets('search narrows the list', (t) async {
      ignoreOverflow();
      await t.pumpWidget(_host(const StockPage(), repo(), admin: false));
      await t.pump();
      await t.pump();

      await t.enterText(find.byKey(const Key('stock_search')), 'air');
      await t.pump();
      expect(find.text('AF25550'), findsOneWidget);
      expect(find.text('LF3000'), findsNothing);
    });

    testWidgets('admin receives stock for a part', (t) async {
      ignoreOverflow();
      final r = repo();
      await t.pumpWidget(_host(const StockPage(), r, admin: true));
      await t.pump();
      await t.pump();

      await t.tap(find.byKey(const Key('receive_stock')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('BAT-31').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.enterText(find.byKey(const Key('stock_qty')), '6');
      await t.tap(find.byKey(const Key('stock_save')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(computeStock(await r.parts(), await r.movements())
          .firstWhere((l) => l.part.id == '3')
          .onHand, 6);
    });

    testWidgets('an adjustment needs a reason', (t) async {
      ignoreOverflow();
      final r = repo();
      await t.pumpWidget(_host(const StockPage(), r, admin: true));
      await t.pump();
      await t.pump();

      await t.tap(find.text('AF25550'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('action_adjust')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byKey(const Key('stock_qty')), '-2');
      await t.tap(find.byKey(const Key('stock_save')));
      await t.pump();

      expect(find.textContaining('Say why'), findsOneWidget);
      expect((await r.movements()).length, 2);
    });
  });

  group('PartsCatalogPage', () {
    testWidgets('admin adds a part and duplicates are refused', (t) async {
      ignoreOverflow();
      final r = repo();
      await t.pumpWidget(_host(const PartsCatalogPage(), r, admin: true));
      await t.pump();
      await t.pump();

      Future<void> add(String number) async {
        await t.tap(find.byKey(const Key('add_part')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.enterText(find.byKey(const Key('part_number')), number);
        await t.ensureVisible(find.byKey(const Key('part_save')));
        await t.tap(find.byKey(const Key('part_save')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }

      await add('NEW-1');
      expect((await r.parts()).any((p) => p.partNumber == 'NEW-1'), isTrue);

      await add('new 1');
      expect(find.textContaining('already in the catalog'), findsOneWidget);
      expect((await r.parts()).where((p) => partKey(p.partNumber) == 'NEW1').length, 1);
    });

    testWidgets('a technician sees the catalog but no add button', (t) async {
      ignoreOverflow();
      await t.pumpWidget(_host(const PartsCatalogPage(), repo(), admin: false));
      await t.pump();
      await t.pump();
      expect(find.text('LF3000'), findsOneWidget);
      expect(find.byKey(const Key('add_part')), findsNothing);
    });
  });
}
