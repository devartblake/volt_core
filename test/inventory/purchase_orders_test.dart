import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/equipment/presenter/asset_code_scanner.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/job_needs.dart';
import 'package:voltcore/modules/inventory/domain/purchase_order.dart';
import 'package:voltcore/modules/inventory/domain/reorder.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/vendor.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/infra/orders_repository.dart';
import 'package:voltcore/modules/inventory/infra/pricing_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/job_needs_providers.dart';
import 'package:voltcore/modules/inventory/presenter/pages/parts_catalog_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/purchase_orders_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/shortages_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/stock_page.dart';

final _t = DateTime.utc(2026, 1, 1);

CatalogPart _part(String id, String n, {String name = '', int min = 0, List<String> alts = const []}) =>
    CatalogPart(
        id: id,
        partNumber: n,
        name: name,
        minStock: min,
        altPartNumbers: alts,
        createdAt: _t,
        updatedAt: _t);

Vendor _vendor(String id, String name) =>
    Vendor(id: id, name: name, createdAt: _t, updatedAt: _t);

PartPrice _price(String id, String part, String vendor, int cents, {int day = 1}) => PartPrice(
    id: id,
    partId: part,
    vendorId: vendor,
    unitCents: cents,
    pricedAt: DateTime.utc(2026, 1, day),
    createdAt: DateTime.utc(2026, 1, day));

PurchaseOrder _order(
  String id,
  String number,
  PoStatus status,
  List<PoLine> lines, {
  String vendor = 'v1',
}) =>
    PurchaseOrder(
        id: id,
        number: number,
        vendorId: vendor,
        status: status,
        createdAt: _t,
        updatedAt: _t,
        lines: lines);

Shortage _short(CatalogPart? p, int needed, int available) => Shortage(
    partNumber: p?.partNumber ?? 'X',
    name: p?.name ?? '',
    part: p,
    needed: needed,
    available: available,
    jobs: 1);

StockLevel _level(CatalogPart p, int onHand) => StockLevel(part: p, onHand: onHand, reserved: 0);

void main() {
  // ------------------------------------------------------------ domain
  group('purchase order domain', () {
    test('provisional numbers are per order and show as pending', () {
      expect(provisionalPoNumber('0a1b2c3d-1111-2222-3333-444455556666'),
          'NEW-0A1B2C3D');
      expect(provisionalPoNumber('ab'), 'NEW-AB');
      expect(isProvisionalPoNumber('NEW-0A1B2C3D'), isTrue);
      expect(isProvisionalPoNumber('PO-0001'), isFalse);
      expect(isProvisionalPoNumber('PO-NEW-1'), isFalse);
      expect(poNumberLabel('NEW-0A1B2C3D'), 'Number pending');
      expect(poNumberLabel('PO-0007'), 'PO-0007');
      final p = _order('o', 'NEW-ABCD1234', PoStatus.draft, const []);
      expect(p.numberPending, isTrue);
      expect(p.displayNumber, 'Number pending');
      expect(_order('o', 'PO-0001', PoStatus.draft, const []).numberPending,
          isFalse);
    });

    test('totals', () {
      final o = _order('o', 'PO-0001', PoStatus.draft, const [
        PoLine(id: 'a', partId: 'p1', qtyOrdered: 2, unitCents: 1050),
        PoLine(id: 'b', partId: 'p2', qtyOrdered: 3, qtyReceived: 1, unitCents: 200),
      ]);
      expect(o.totalCents, 2 * 1050 + 3 * 200);
      expect(o.unitsOrdered, 5);
      expect(o.unitsReceived, 1);
      expect(o.lines.last.outstanding, 2);
    });

    test('status transitions', () {
      expect(canTransition(PoStatus.draft, PoStatus.sent), isTrue);
      expect(canTransition(PoStatus.draft, PoStatus.received), isFalse);
      expect(canTransition(PoStatus.sent, PoStatus.cancelled), isTrue);
      expect(canTransition(PoStatus.received, PoStatus.sent), isFalse);
      expect(canTransition(PoStatus.cancelled, PoStatus.draft), isFalse);
      expect(canTransition(PoStatus.sent, PoStatus.sent), isFalse);
    });

    test('statusAfterReceipt', () {
      PurchaseOrder withReceived(PoStatus s, int a, int b) => _order('o', 'PO-1', s, [
            PoLine(id: 'a', partId: 'p1', qtyOrdered: 2, qtyReceived: a),
            PoLine(id: 'b', partId: 'p2', qtyOrdered: 3, qtyReceived: b),
          ]);
      expect(statusAfterReceipt(withReceived(PoStatus.sent, 0, 0)), PoStatus.sent);
      expect(statusAfterReceipt(withReceived(PoStatus.sent, 1, 0)), PoStatus.partial);
      expect(statusAfterReceipt(withReceived(PoStatus.partial, 2, 3)), PoStatus.received);
      expect(statusAfterReceipt(withReceived(PoStatus.draft, 2, 3)), PoStatus.draft);
      expect(statusAfterReceipt(withReceived(PoStatus.cancelled, 2, 3)), PoStatus.cancelled);
    });

    test('on order counts only sent and partly received orders', () {
      final m = onOrderByPart([
        _order('1', 'PO-1', PoStatus.sent, const [PoLine(id: 'a', partId: 'p1', qtyOrdered: 5)]),
        _order('2', 'PO-2', PoStatus.partial, const [
          PoLine(id: 'b', partId: 'p1', qtyOrdered: 4, qtyReceived: 3),
          PoLine(id: 'c', partId: 'p2', qtyOrdered: 2, qtyReceived: 2),
        ]),
        _order('3', 'PO-3', PoStatus.draft, const [PoLine(id: 'd', partId: 'p1', qtyOrdered: 9)]),
        _order('4', 'PO-4', PoStatus.cancelled, const [PoLine(id: 'e', partId: 'p1', qtyOrdered: 9)]),
        _order('5', 'PO-5', PoStatus.received, const [PoLine(id: 'f', partId: 'p3', qtyOrdered: 9, qtyReceived: 9)]),
      ]);
      expect(m, {'p1': 6});
    });

    test('share text lists vendor, lines and total', () {
      final o = _order('o', 'PO-0002', PoStatus.draft, const [
        PoLine(id: 'a', partId: 'p1', qtyOrdered: 2, unitCents: 1050, vendorPartNumber: 'V-1'),
      ]);
      final text = poShareText(o,
          vendorName: 'Ace',
          partLabel: (_) => 'LF3000',
          money: formatCents);
      expect(text, contains('PO-0002'));
      expect(text, contains('Vendor: Ace'));
      expect(text, contains('2 x LF3000 (vendor #V-1) @ \$10.50 = \$21.00'));
      expect(text, contains('Total: \$21.00'));
    });
  });

  group('reorder lines', () {
    final oil = _part('p1', 'LF3000', min: 4);
    final air = _part('p2', 'AF25550');

    test('shortage order quantity subtracts what is on order', () {
      final s = _short(oil, 8, 2); // short by 6
      expect(shortageOrderQty(s, const {}), 6);
      expect(shortageOrderQty(s, {'p1': 4}), 2);
      expect(shortageOrderQty(s, {'p1': 10}), 0);
      expect(shortageOrderQty(_short(null, 3, 0), {'p1': 10}), 3);
    });

    test('combines job shortages and low stock, minus open orders', () {
      final lines = buildReorderLines(
        [_short(air, 5, 1), _short(null, 2, 0), _short(oil, 3, 0)],
        [_level(oil, 1)], // minimum 4, available 1 -> wants 3
        {'p2': 1},
      );
      expect(lines.map((l) => l.part.id), ['p2', 'p1']);
      final byId = {for (final l in lines) l.part.id: l};
      expect(byId.length, 2, reason: 'uncatalogued parts are left out');
      expect(byId['p2']!.wanted, 4);
      expect(byId['p2']!.orderQty, 3);
      expect(byId['p1']!.wanted, 3);
      expect(byId['p1']!.forJobs && byId['p1']!.belowMin, isTrue);
    });

    test('a part fully on order has nothing left to order', () {
      final lines = buildReorderLines([_short(air, 2, 0)], const [], {'p2': 5});
      expect(lines.single.orderQty, 0);
      expect(lines.single.coveredByOrder, isTrue);
      expect(groupByBestVendor(lines, const {}), isEmpty);
    });

    test('low stock wants at least one', () {
      expect(lowStockWanted(_level(_part('p', 'A', min: 3), 3)), 1);
      expect(lowStockWanted(_level(_part('p', 'A', min: 5), 2)), 3);
    });

    test('groups by best vendor; unpriced parts have no vendor yet', () {
      final lines = buildReorderLines(
          [_short(oil, 4, 0), _short(air, 2, 0)], const [], const {});
      final groups = groupByBestVendor(lines, {
        'p1': [
          _price('a', 'p1', 'v1', 1500),
          _price('b', 'p1', 'v2', 1200),
        ],
      });
      expect(groups.keys.toSet(), {'v2', noVendorGroup});
      final v2 = groups['v2']!.single;
      expect(v2.part.id, 'p1');
      expect(v2.qty, 4);
      expect(v2.unitCents, 1200);
      expect(groups[noVendorGroup]!.single.part.id, 'p2');
      expect(groups[noVendorGroup]!.single.unitCents, 0);
    });
  });

  // ------------------------------------------------------------ repository
  group('OrdersRepository', () {
    late OrdersRepository repo;
    late _RecInventory inv;
    late _RecPricing pricing;
    late List<String> upserts;
    late List<String> deletes;
    var n = 0;

    setUp(() async {
      Hive.init('${Directory.systemTemp.path}/po_test_${DateTime.now().microsecondsSinceEpoch}');
      n++;
      upserts = [];
      deletes = [];
      var ids = 0;
      repo = OrdersRepository(
        ordersBox: await Hive.openBox<String>('o$n'),
        linesBox: await Hive.openBox<String>('l$n'),
        receiptsBox: await Hive.openBox<String>('r$n'),
        upsert: (table, id, row) async => upserts.add('$table:$id'),
        delete: (table, id) async => deletes.add('$table:$id'),
        fetch: (_) async => const [],
        tenantId: () => 't1',
        userId: () => 'u1',
        newId: () => 'id${ids++}',
        now: () => DateTime.utc(2026, 2, 1),
      );
      inv = _RecInventory();
      pricing = _RecPricing();
    });

    Future<PurchaseOrder> sentOrder() async {
      final o = await repo.newOrder(vendorId: 'v1', lines: [
        repo.newLine(partId: 'p1', qty: 5, unitCents: 1000, vendorPartNumber: 'V-1'),
        repo.newLine(partId: 'p2', qty: 2, unitCents: 300),
      ]);
      await repo.saveOrder(o);
      await repo.setStatus(o.id, PoStatus.sent);
      return (await repo.order(o.id))!;
    }

    test('new orders get a provisional number and reject a duplicate number', () async {
      final a = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 1)]);
      expect(a.number, provisionalPoNumber(a.id));
      expect(a.numberPending, isTrue);
      await repo.saveOrder(a);
      final b = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 1)]);
      expect(b.number, isNot(a.number));
      await repo.saveOrder(b.copyWith(number: 'PO-0001'));
      await expectLater(repo.saveOrder(a.copyWith(number: 'po-0001')),
          throwsA(isA<DuplicatePoNumberException>()));
      await repo.saveOrder(a.copyWith(number: 'PO-A12'));
      expect((await repo.orders()).map((o) => o.number), containsAll(['PO-0001', 'PO-A12']));
    });

    test('refreshFromCloud adopts the server number and keeps newer local edits', () async {
      final o = await repo.newOrder(vendorId: 'v1', lines: [
        repo.newLine(partId: 'p1', qty: 3),
      ]);
      await repo.saveOrder(o);
      final local = (await repo.order(o.id))!;
      final synced = OrdersRepository(
        ordersBox: repo.debugOrdersBox,
        linesBox: repo.debugLinesBox,
        receiptsBox: repo.debugReceiptsBox,
        tenantId: () => null,
        fetch: (table) async => table == kPurchaseOrdersTable
            ? [
                {
                  'id': o.id,
                  'po_number': 'PO-0042',
                  'vendor_id': 'v1',
                  'status': 'draft',
                  'note': '',
                  'created_at': local.createdAt.toIso8601String(),
                  // Not newer than the local copy.
                  'updated_at': local.updatedAt.toIso8601String(),
                }
              ]
            : const [],
      );
      expect(await synced.refreshFromCloud(), 1);
      final after = (await synced.order(o.id))!;
      expect(after.number, 'PO-0042');
      expect(after.id, o.id);
      expect(after.lines.single.qtyOrdered, 3);
      expect(after.updatedAt, local.updatedAt);
      expect(await synced.refreshFromCloud(), 0);
    });

    test('a custom number is kept and never treated as pending', () async {
      final o = await repo.newOrder(
          vendorId: 'v1',
          number: 'ACME-77',
          lines: [repo.newLine(partId: 'p1', qty: 1)]);
      expect(o.number, 'ACME-77');
      expect(o.numberPending, isFalse);
    });

    test('saves lines, queues sync rows, and removes dropped lines', () async {
      final o = await repo.newOrder(vendorId: 'v1', lines: [
        repo.newLine(partId: 'p1', qty: 2, unitCents: 500),
        repo.newLine(partId: 'p2', qty: 1),
      ]);
      await repo.saveOrder(o);
      expect(upserts, contains('purchase_orders:${o.id}'));
      expect(upserts.where((u) => u.startsWith('purchase_order_lines:')).length, 2);

      final dropped = o.lines.first;
      await repo.saveOrder(o.copyWith(lines: [o.lines.last]));
      final back = (await repo.order(o.id))!;
      expect(back.lines.map((l) => l.id), [o.lines.last.id]);
      expect(deletes, ['purchase_order_lines:${dropped.id}']);
    });

    test('rejects a zero quantity', () async {
      final o = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 0)]);
      await expectLater(repo.saveOrder(o), throwsArgumentError);
    });

    test('status changes follow the allowed transitions', () async {
      final o = await sentOrder();
      expect(o.status, PoStatus.sent);
      await expectLater(repo.setStatus(o.id, PoStatus.draft), throwsStateError);
      await repo.setStatus(o.id, PoStatus.cancelled);
      expect((await repo.order(o.id))!.status, PoStatus.cancelled);
    });

    test('only a draft can be deleted', () async {
      final sent = await sentOrder();
      await expectLater(repo.deleteDraft(sent.id), throwsStateError);
      final d = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 1)]);
      await repo.saveOrder(d);
      await repo.deleteDraft(d.id);
      expect(await repo.order(d.id), isNull);
      expect(deletes, contains('purchase_orders:${d.id}'));
    });

    test('receiving adds a ledger movement, a paid price and updates status', () async {
      final o = await sentOrder();
      final p1 = o.lines.firstWhere((l) => l.partId == 'p1');

      final r = await repo.receive(
        orderId: o.id,
        receiptId: 'r1',
        quantities: {p1.id: 3},
        inventory: inv,
        pricing: pricing,
      );
      expect(r.applied, isTrue);
      expect(inv.records, ['p1 +3 receive ${o.number}']);
      expect(pricing.added, ['p1 v1 1000 V-1 ${o.number}']);
      expect(r.order.status, PoStatus.partial);
      expect(r.order.lines.firstWhere((l) => l.partId == 'p1').qtyReceived, 3);
      expect(await repo.onOrder(), {'p1': 2, 'p2': 2});

      final p2 = o.lines.firstWhere((l) => l.partId == 'p2');
      final r2 = await repo.receive(
        orderId: o.id,
        receiptId: 'r2',
        quantities: {p1.id: 2, p2.id: 2},
        inventory: inv,
        pricing: pricing,
      );
      expect(r2.order.status, PoStatus.received);
      expect(inv.records.length, 3);
      expect(await repo.onOrder(), isEmpty);
    });

    test('the same receive action never adds stock twice', () async {
      final o = await sentOrder();
      final p1 = o.lines.first;
      for (var i = 0; i < 3; i++) {
        final r = await repo.receive(
          orderId: o.id,
          receiptId: 'same',
          quantities: {p1.id: 2},
          inventory: inv,
          pricing: pricing,
        );
        expect(r.applied, i == 0);
      }
      expect(inv.records.length, 1);
      expect(pricing.added.length, 1);
      expect((await repo.order(o.id))!.lines.first.qtyReceived, 2);
    });

    test('cannot receive against a draft', () async {
      final d = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 1)]);
      await repo.saveOrder(d);
      await expectLater(
        repo.receive(
            orderId: d.id,
            receiptId: 'x',
            quantities: {d.lines.first.id: 1},
            inventory: inv,
            pricing: pricing),
        throwsStateError,
      );
      expect(inv.records, isEmpty);
    });

    test('a line with no price receives stock but records no price', () async {
      final o = await repo.newOrder(vendorId: 'v1', lines: [repo.newLine(partId: 'p1', qty: 2)]);
      await repo.saveOrder(o);
      await repo.setStatus(o.id, PoStatus.sent);
      await repo.receive(
          orderId: o.id,
          receiptId: 'z',
          quantities: {o.lines.first.id: 2},
          inventory: inv,
          pricing: pricing);
      expect(inv.records.length, 1);
      expect(pricing.added, isEmpty);
    });

    test('reorder history lists a part\'s lines, skipping cancelled orders', () async {
      final a = await sentOrder();
      final b = await repo.newOrder(vendorId: 'v2', lines: [repo.newLine(partId: 'p1', qty: 9)]);
      await repo.saveOrder(b);
      await repo.setStatus(b.id, PoStatus.cancelled);
      final h = await repo.historyFor('p1');
      expect(h.map((e) => e.order.id), [a.id]);
    });

    test('refreshFromCloud takes newer orders and missing lines', () async {
      final remote = OrdersRepository(
        ordersBox: await Hive.openBox<String>('o2_$n'),
        linesBox: await Hive.openBox<String>('l2_$n'),
        receiptsBox: await Hive.openBox<String>('r2_$n'),
        tenantId: () => null,
        fetch: (table) async => table == kPurchaseOrdersTable
            ? [
                {
                  'id': 'o9',
                  'po_number': 'PO-0009',
                  'vendor_id': 'v1',
                  'status': 'sent',
                  'expected_on': '2026-03-01',
                  'note': 'n',
                  'created_at': '2026-02-01T00:00:00Z',
                  'updated_at': '2026-02-01T00:00:00Z',
                }
              ]
            : [
                {
                  'id': 'l9',
                  'order_id': 'o9',
                  'part_id': 'p1',
                  'qty_ordered': 4,
                  'qty_received': 1,
                  'unit_price_cents': 250,
                  'vendor_part_number': 'V',
                }
              ],
      );
      expect(await remote.refreshFromCloud(), 2);
      final o = (await remote.order('o9'))!;
      expect(o.number, 'PO-0009');
      expect(o.status, PoStatus.sent);
      expect(o.expectedOn, isNotNull);
      expect(o.lines.single.qtyReceived, 1);
      expect(await remote.onOrder(), {'p1': 3});
      expect(await remote.refreshFromCloud(), 0);
    });
  });

  // ------------------------------------------------------------ pages
  group('Shortages and purchase orders', () {
    void quiet() {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
    }

    final oil = _part('p1', 'LF3000', name: 'Oil filter');
    final air = _part('p2', 'AF25550', name: 'Air filter');
    final belt = _part('p3', 'BELT-9', name: 'Belt', min: 4);

    Widget host(
      Widget page, {
      required _MemOrders orders,
      bool admin = true,
      Map<String, int>? onOrder,
      double scale = 1.0,
    }) {
      final pricing = _MemPricing(
        [_vendor('v1', 'Ace'), _vendor('v2', 'Bolt')],
        [_price('a', 'p1', 'v1', 1500), _price('b', 'p1', 'v2', 1200)],
      );
      return ProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWithValue(admin),
          canReserveStockProvider.overrideWithValue(admin),
          ordersRepositoryProvider.overrideWithValue(orders),
          pricingRepositoryProvider.overrideWithValue(pricing),
          inventoryRepositoryProvider.overrideWithValue(_MemInventory([oil, air, belt], [])),
          if (onOrder != null) onOrderProvider.overrideWith((ref) async => onOrder),
          shortagesProvider.overrideWith((ref) async => [_short(oil, 4, 0), _short(air, 2, 0)]),
          lowStockProvider.overrideWith((ref) async => [_level(belt, 1)]),
        ],
        child: MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: c!,
          ),
          home: page,
        ),
      );
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('admin creates draft orders grouped by best vendor', (t) async {
      quiet();
      final orders = _MemOrders();
      await t.pumpWidget(host(const ShortagesPage(), orders: orders));
      await settle(t);

      expect(find.byKey(const Key('create_pos')), findsOneWidget);
      await t.tap(find.byKey(const Key('create_pos')));
      await settle(t);

      // LF3000 -> cheapest vendor (Bolt, 12.00). AF25550 and BELT-9 have no price.
      expect(find.text('Bolt'), findsOneWidget);
      expect(find.text('No vendor yet'), findsOneWidget);
      expect((t.widget(find.byKey(const Key('po_price_p1'))) as TextField).controller!.text, '12.00');
      expect((t.widget(find.byKey(const Key('po_qty_p1'))) as TextField).controller!.text, '4');
      expect((t.widget(find.byKey(const Key('po_qty_p3'))) as TextField).controller!.text, '3',
          reason: 'minimum 4 - available 1');

      // Edit a quantity, drop a line, and give the unpriced group a vendor.
      await t.enterText(find.byKey(const Key('po_qty_p1')), '6');
      t.widget<IconButton>(find.byKey(const Key('po_drop_p3'))).onPressed!();
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('po_vendor_1')));
      await t.pump();
      await t.tap(find.byKey(const Key('po_vendor_1')));
      await settle(t);
      await t.tap(find.text('Ace').last);
      await settle(t);
      await t.ensureVisible(find.byKey(const Key('po_save')));
      await t.tap(find.byKey(const Key('po_save')));
      await settle(t);

      expect(orders.saved.length, 2);
      final bolt = orders.saved.firstWhere((o) => o.vendorId == 'v2');
      expect(bolt.status, PoStatus.draft);
      expect(bolt.lines.single.partId, 'p1');
      expect(bolt.lines.single.qtyOrdered, 6);
      expect(bolt.lines.single.unitCents, 1200);
      final ace = orders.saved.firstWhere((o) => o.vendorId == 'v1');
      expect(ace.lines.single.partId, 'p2');
      expect(ace.number, isNot(bolt.number));
    });

    testWidgets('lines left without a vendor block saving', (t) async {
      quiet();
      final orders = _MemOrders();
      await t.pumpWidget(host(const ShortagesPage(), orders: orders));
      await settle(t);
      await t.tap(find.byKey(const Key('create_pos')));
      await settle(t);
      // Remove the priced line so only unassigned ones remain.
      t.widget<IconButton>(find.byKey(const Key('po_drop_p1'))).onPressed!();
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('po_save')));
      await t.tap(find.byKey(const Key('po_save')));
      await settle(t);
      expect(find.text('Choose a vendor for the parts without one.'), findsOneWidget);
      expect(orders.saved, isEmpty);
    });

    testWidgets('on-order quantity is subtracted and shown as a chip', (t) async {
      quiet();
      await t.pumpWidget(
          host(const ShortagesPage(), orders: _MemOrders(), onOrder: {'p1': 3, 'p2': 5}));
      await settle(t);
      // LF3000 short 4, 3 on order -> order 1. AF25550 short 2, 5 on order -> covered.
      expect(find.text('Order 1'), findsOneWidget);
      expect(find.text('Covered'), findsOneWidget);
      expect(find.text('On order 3'), findsOneWidget);
      expect(find.text('On order 5'), findsOneWidget);
    });

    testWidgets('non-admins see no ordering and no on-order chips', (t) async {
      quiet();
      await t.pumpWidget(host(const ShortagesPage(),
          orders: _MemOrders(), admin: false, onOrder: {'p1': 3}));
      await settle(t);
      expect(find.byKey(const Key('create_pos')), findsNothing);
      expect(find.text('Order 4'), findsOneWidget);
      expect(find.byKey(const Key('on_order_chip')), findsNothing);
    });

    testWidgets('when everything is on order the button is disabled', (t) async {
      quiet();
      await t.pumpWidget(host(const ShortagesPage(),
          orders: _MemOrders(), onOrder: {'p1': 9, 'p2': 9, 'p3': 9}));
      await settle(t);
      final b = t.widget<FilledButton>(find.byKey(const Key('create_pos')));
      expect(b.onPressed, isNull);
      expect(find.text('Everything is on order'), findsOneWidget);
    });

    testWidgets('orders list shows status and totals; detail marks sent and receives',
        (t) async {
      quiet();
      final inv = _MemInventory([oil, air], []);
      final orders = _MemOrders(initial: [
        _order('o1', 'PO-0001', PoStatus.draft, const [
          PoLine(id: 'l1', partId: 'p1', qtyOrdered: 4, unitCents: 1200),
          PoLine(id: 'l2', partId: 'p2', qtyOrdered: 2, unitCents: 500),
        ]),
        _order('o2', 'PO-0002', PoStatus.received, const [
          PoLine(id: 'l3', partId: 'p1', qtyOrdered: 1, qtyReceived: 1, unitCents: 100),
        ], vendor: 'v2'),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWithValue(true),
          ordersRepositoryProvider.overrideWithValue(orders),
          pricingRepositoryProvider.overrideWithValue(
              _MemPricing([_vendor('v1', 'Ace'), _vendor('v2', 'Bolt')], [])),
          inventoryRepositoryProvider.overrideWithValue(inv),
        ],
        child: const MaterialApp(home: PurchaseOrdersPage()),
      ));
      await settle(t);

      expect(find.text('PO-0001 · Ace'), findsOneWidget);
      expect(find.text('PO-0002 · Bolt'), findsOneWidget);
      expect(find.textContaining('\$58.00'), findsOneWidget); // 4*12 + 2*5
      await t.tap(find.byKey(const Key('po_filter_received')));
      await t.pump();
      expect(find.text('PO-0001 · Ace'), findsNothing);
      await t.tap(find.text('All'));
      await t.pump();

      await t.tap(find.text('PO-0001 · Ace'));
      await settle(t);
      expect(find.byKey(const Key('po_receive')), findsNothing, reason: 'draft');
      await t.tap(find.byKey(const Key('po_mark_sent')));
      await settle(t);
      expect(orders.byId('o1').status, PoStatus.sent);
      expect(find.byKey(const Key('po_mark_sent')), findsNothing);

      await t.tap(find.byKey(const Key('po_receive')));
      await settle(t);
      await t.enterText(find.byKey(const Key('receive_qty_l1')), '3');
      await t.tap(find.byKey(const Key('po_receive_confirm')));
      await settle(t);

      expect(orders.receiveCalls.length, 1);
      expect(orders.receiveCalls.single.quantities, {'l1': 3, 'l2': 2});
      expect(orders.byId('o1').status, PoStatus.partial);
      expect(find.text('Partly received'), findsWidgets);
    });

    testWidgets('orders list builds rows lazily (300 orders)', (t) async {
      quiet();
      t.view.physicalSize = const Size(400, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final orders = _MemOrders(initial: [
        for (var i = 0; i < 300; i++)
          _order('o$i', 'PO-$i', PoStatus.draft, const [
            PoLine(id: 'l', partId: 'p1', qtyOrdered: 1, unitCents: 100),
          ]),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWithValue(true),
          ordersRepositoryProvider.overrideWithValue(orders),
          pricingRepositoryProvider
              .overrideWithValue(_MemPricing([_vendor('v1', 'Ace')], [])),
          inventoryRepositoryProvider
              .overrideWithValue(_MemInventory([oil, air], [])),
        ],
        child: const MaterialApp(home: PurchaseOrdersPage()),
      ));
      await settle(t);
      expect(find.byType(ListTile).evaluate().length, lessThan(60));
      expect(find.byType(ListTile).evaluate().length, greaterThan(3));
      await t.scrollUntilVisible(find.text('PO-299 · Ace'), 500,
          maxScrolls: 400,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('PO-299 · Ace'), findsOneWidget);
    });

    testWidgets('receiving more than is outstanding is refused', (t) async {
      quiet();
      final orders = _MemOrders(initial: [
        _order('o1', 'PO-0001', PoStatus.sent, const [
          PoLine(id: 'l1', partId: 'p1', qtyOrdered: 2, unitCents: 100),
        ]),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWithValue(true),
          ordersRepositoryProvider.overrideWithValue(orders),
          pricingRepositoryProvider.overrideWithValue(_MemPricing([_vendor('v1', 'Ace')], [])),
          inventoryRepositoryProvider.overrideWithValue(_MemInventory([oil], [])),
        ],
        child: const MaterialApp(home: PurchaseOrderDetailPage(orderId: 'o1')),
      ));
      await settle(t);
      await t.tap(find.byKey(const Key('po_receive')));
      await settle(t);
      await t.enterText(find.byKey(const Key('receive_qty_l1')), '5');
      await t.tap(find.byKey(const Key('po_receive_confirm')));
      await settle(t);
      expect(find.textContaining('only 2 still to arrive'), findsOneWidget);
      expect(orders.receiveCalls, isEmpty);
    });

    testWidgets('editing an order changes quantity, price and number', (t) async {
      quiet();
      final orders = _MemOrders(initial: [
        _order('o1', 'PO-0001', PoStatus.draft, const [
          PoLine(id: 'l1', partId: 'p1', qtyOrdered: 2, unitCents: 100),
          PoLine(id: 'l2', partId: 'p2', qtyOrdered: 1, unitCents: 100),
        ]),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          canManageInventoryProvider.overrideWithValue(true),
          ordersRepositoryProvider.overrideWithValue(orders),
          pricingRepositoryProvider.overrideWithValue(_MemPricing([_vendor('v1', 'Ace')], [])),
          inventoryRepositoryProvider.overrideWithValue(_MemInventory([oil, air], [])),
        ],
        child: const MaterialApp(home: PurchaseOrderDetailPage(orderId: 'o1')),
      ));
      await settle(t);
      await t.tap(find.byKey(const Key('po_edit')));
      await settle(t);
      await t.enterText(find.byKey(const Key('po_number')), 'PO-77');
      await t.enterText(find.byKey(const Key('po_edit_qty_l1')), '7');
      await t.enterText(find.byKey(const Key('po_edit_price_l1')), '2.50');
      await t.tap(find.byKey(const Key('po_edit_drop_l2')));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('po_edit_save')));
      await t.tap(find.byKey(const Key('po_edit_save')));
      await settle(t);
      final o = orders.byId('o1');
      expect(o.number, 'PO-77');
      expect(o.lines.length, 1);
      expect(o.lines.single.qtyOrdered, 7);
      expect(o.lines.single.unitCents, 250);
      expect(find.byKey(const Key('po_total')), findsOneWidget);
      expect(find.text('Total \$17.50'), findsOneWidget);
    });

    for (final s in [const Size(360, 740), const Size(900, 1100)]) {
      for (final page in ['review', 'orders']) {
        testWidgets('$page at 1.3x text on ${s.width.toInt()} wide', (t) async {
          final orders = _MemOrders(initial: [
            _order('o1', 'PO-0001', PoStatus.sent, const [
              PoLine(id: 'l1', partId: 'p1', qtyOrdered: 4, unitCents: 1200),
            ]),
          ]);
          t.view.physicalSize = s;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final errors = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.toString().split(String.fromCharCode(10)).take(40).join(' | '));

          await t.pumpWidget(host(
            page == 'review' ? const ShortagesPage() : const PurchaseOrdersPage(),
            orders: orders,
            scale: 1.3,
          ));
          await settle(t);
          if (page == 'review') {
            await t.tap(find.byKey(const Key('create_pos')));
            await settle(t);
            expect(find.byKey(const Key('po_save')), findsOneWidget);
          } else {
            expect(find.textContaining('PO-0001'), findsOneWidget);
          }
          // Layout problems may only be overflow warnings from the shell; no
          // other framework error is acceptable.
          FlutterError.onError = prev;
          expect(errors, isEmpty, reason: 'no overflow or other error at 1.3x');
        });
      }
    }
  });

  // ------------------------------------------------------------ barcode
  group('barcode for parts', () {
    final oil = _part('p1', 'LF3000', name: 'Oil filter', alts: ['LF-3000-ALT']);
    final air = _part('p2', 'AF25550', name: 'Air filter');

    void quiet() {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
    }

    Widget host(Widget page, _FakeScanner scanner, {bool admin = true}) {
      final inv = _MemInventory([oil, air], [
        InventoryMovement(id: 'm1', partId: 'p1', qtyDelta: 3, reason: MovementReason.receive, at: _t),
        InventoryMovement(id: 'm2', partId: 'p2', qtyDelta: 3, reason: MovementReason.receive, at: _t),
      ]);
      return ProviderScope(
        overrides: [
          assetCodeScannerProvider.overrideWithValue(scanner),
          canManageInventoryProvider.overrideWithValue(admin),
          canReserveStockProvider.overrideWithValue(admin),
          inventoryRepositoryProvider.overrideWithValue(inv),
          inventoryLocationsProvider.overrideWith((ref) async => [InventoryLocation.main()]),
          pricingRepositoryProvider.overrideWithValue(_MemPricing(const [], const [])),
          ordersRepositoryProvider.overrideWithValue(_MemOrders()),
        ],
        child: MaterialApp(home: page),
      );
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('no Scan button where scanning is not supported', (t) async {
      quiet();
      await t.pumpWidget(host(const StockPage(), _FakeScanner(supported: false)));
      await settle(t);
      expect(find.byKey(const Key('scan_part')), findsNothing);
    });

    testWidgets('stock: an exact part number opens that part', (t) async {
      quiet();
      final scanner = _FakeScanner(result: 'lf-3000-alt');
      await t.pumpWidget(host(const StockPage(), scanner));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      expect(scanner.scans, 1);
      expect((t.widget(find.byKey(const Key('stock_search'))) as TextField).controller!.text,
          'lf-3000-alt');
      // The part sheet is open (its Edit button is there for an admin).
      expect(find.byKey(const Key('edit_part')), findsOneWidget);
      expect(find.text('Alternates: LF-3000-ALT'), findsOneWidget);
    });

    testWidgets('stock: an unknown code fills the search and offers admins to add it',
        (t) async {
      quiet();
      await t.pumpWidget(host(const StockPage(), _FakeScanner(result: 'ZZ-999')));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.text('Add this part'), findsOneWidget);
      await t.tap(find.byKey(const Key('add_scanned_part')));
      await settle(t);
      expect((t.widget(find.byKey(const Key('part_number'))) as TextField).controller!.text,
          'ZZ-999');
    });

    testWidgets('stock: a technician is not offered to add an unknown part', (t) async {
      quiet();
      await t.pumpWidget(host(const StockPage(), _FakeScanner(result: 'ZZ-999'), admin: false));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.text('Add this part'), findsNothing);
    });

    testWidgets('a cancelled scan changes nothing', (t) async {
      quiet();
      await t.pumpWidget(host(const StockPage(), _FakeScanner(result: null)));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      expect((t.widget(find.byKey(const Key('stock_search'))) as TextField).controller!.text, '');
    });

    testWidgets('catalog: exact match opens the editor for admins', (t) async {
      quiet();
      await t.pumpWidget(host(const PartsCatalogPage(), _FakeScanner(result: 'AF25550')));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      expect((t.widget(find.byKey(const Key('part_number'))) as TextField).controller!.text,
          'AF25550');
      expect(find.text('Edit part'), findsOneWidget);
    });

    testWidgets('catalog: unknown code offers Add this part, prefilled', (t) async {
      quiet();
      await t.pumpWidget(host(const PartsCatalogPage(), _FakeScanner(result: ' NEW-1 ')));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')));
      await settle(t);
      await t.tap(find.byKey(const Key('add_scanned_part')));
      await settle(t);
      expect((t.widget(find.byKey(const Key('part_number'))) as TextField).controller!.text,
          'NEW-1');
      expect(find.text('Add part'), findsWidgets);
    });

    testWidgets('receive-stock picker: scan picks the part, else fills search', (t) async {
      quiet();
      final scanner = _FakeScanner(result: 'AF25550');
      await t.pumpWidget(host(const StockPage(), scanner));
      await settle(t);
      await t.tap(find.byKey(const Key('receive_stock')));
      await settle(t);
      // Two Scan buttons now: the page's and the picker's (last).
      await t.tap(find.byKey(const Key('scan_part')).last);
      await settle(t);
      // The receive sheet for AF25550 opened.
      expect(find.byKey(const Key('stock_qty')), findsOneWidget);
    });

    testWidgets('picker: an unmatched scan fills the search', (t) async {
      quiet();
      final scanner = _FakeScanner(result: 'filter');
      await t.pumpWidget(host(const StockPage(), scanner));
      await settle(t);
      await t.tap(find.byKey(const Key('receive_stock')));
      await settle(t);
      await t.tap(find.byKey(const Key('scan_part')).last);
      await settle(t);
      expect((t.widget(find.byKey(const Key('picker_search'))) as TextField).controller!.text,
          'filter');
      expect(find.text('LF3000'), findsWidgets);
    });
  });
}

// ------------------------------------------------------------------ fakes

class _FakeScanner implements AssetCodeScanner {
  _FakeScanner({this.supported = true, this.result});
  final bool supported;
  String? result;
  int scans = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<String?> scan(BuildContext context) async {
    scans++;
    return result;
  }
}

class _RecInventory extends InventoryRepository {
  @override
  Future<List<InventoryLocation>> locations({bool includeInactive = false}) async =>
      [InventoryLocation.main()];

  _RecInventory() : super(tenantId: () => null);
  final records = <String>[];

  @override
  Future<InventoryMovement?> record({
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async {
    records.add('$partId ${qty > 0 ? '+' : ''}$qty ${reason.wire} $note');
    return null;
  }
}

class _RecPricing extends PricingRepository {
  _RecPricing() : super(tenantId: () => null);
  final added = <String>[];

  @override
  Future<PartPrice> addPrice({
    required String partId,
    required String vendorId,
    required int unitCents,
    PriceKind kind = PriceKind.paid,
    String vendorPartNumber = '',
    DateTime? pricedAt,
    String note = '',
  }) async {
    added.add('$partId $vendorId $unitCents $vendorPartNumber $note');
    return PartPrice(
        id: 'x',
        partId: partId,
        vendorId: vendorId,
        unitCents: unitCents,
        pricedAt: _t,
        createdAt: _t);
  }
}

class _MemPricing extends PricingRepository {
  _MemPricing(this._vendors, this._prices) : super(tenantId: () => null);
  final List<Vendor> _vendors;
  final List<PartPrice> _prices;

  @override
  Future<List<Vendor>> vendors() async => List.of(_vendors);

  @override
  Future<List<PartPrice>> prices({String? partId}) async => [
        for (final p in _prices)
          if (partId == null || p.partId == partId) p,
      ];

  @override
  Future<int> refreshFromCloud() async => 0;
}

class _MemInventory extends InventoryRepository {
  @override
  Future<List<InventoryLocation>> locations({bool includeInactive = false}) async =>
      [InventoryLocation.main()];

  _MemInventory(this._parts, this._moves) : super(tenantId: () => null);
  final List<CatalogPart> _parts;
  final List<InventoryMovement> _moves;

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
  Future<InventoryMovement?> record({
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async =>
      null;
}

class _ReceiveCall {
  _ReceiveCall(this.orderId, this.receiptId, this.quantities);
  final String orderId;
  final String receiptId;
  final Map<String, int> quantities;
}

/// Orders held in memory: Hive writes never finish on the widget-test clock.
class _MemOrders extends OrdersRepository {
  _MemOrders({List<PurchaseOrder> initial = const []})
      : _orders = {for (final o in initial) o.id: o},
        super(tenantId: () => null, newId: () => 'n${_seq++}');

  static int _seq = 0;
  final Map<String, PurchaseOrder> _orders;
  final saved = <PurchaseOrder>[];
  final receiveCalls = <_ReceiveCall>[];
  final _receipts = <String>{};

  PurchaseOrder byId(String id) => _orders[id]!;

  @override
  Future<List<PurchaseOrder>> orders() async => _orders.values.toList();

  @override
  Future<PurchaseOrder?> order(String id) async => _orders[id];

  @override
  Future<Map<String, int>> onOrder() async => onOrderByPart(_orders.values);

  @override
  Future<int> refreshFromCloud() async => 0;

  @override
  Future<PurchaseOrder> saveOrder(PurchaseOrder o) async {
    final n = o.number.trim();
    for (final other in _orders.values) {
      if (other.id != o.id && other.number.toLowerCase() == n.toLowerCase()) {
        throw DuplicatePoNumberException(n);
      }
    }
    final s = o.copyWith(number: n);
    _orders[s.id] = s;
    saved.add(s);
    return s;
  }

  @override
  Future<ReceiveResult> receive({
    required String orderId,
    required String receiptId,
    required Map<String, int> quantities,
    required InventoryRepository inventory,
    required PricingRepository pricing,
  }) async {
    final o = _orders[orderId]!;
    if (!_receipts.add(receiptId)) return ReceiveResult(order: o, applied: false);
    receiveCalls.add(_ReceiveCall(orderId, receiptId, quantities));
    var next = o.copyWith(lines: [
      for (final l in o.lines)
        l.copyWith(qtyReceived: l.qtyReceived + (quantities[l.id] ?? 0)),
    ]);
    next = next.copyWith(status: statusAfterReceipt(next));
    _orders[orderId] = next;
    return ReceiveResult(order: next, applied: true);
  }
}
