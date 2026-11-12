import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

final _t = DateTime.utc(2026, 1, 1);

CatalogPart part(String id, String number,
        {String name = '', int min = 0, List<String> alts = const [], bool active = true, String mfr = ''}) =>
    CatalogPart(
      id: id,
      partNumber: number,
      name: name,
      manufacturer: mfr,
      minStock: min,
      altPartNumbers: alts,
      isActive: active,
      createdAt: _t,
      updatedAt: _t,
    );

InventoryMovement mv(String part, int q, MovementReason r) => InventoryMovement(
      id: '${part}_${q}_${r.wire}_${DateTime.now().microsecondsSinceEpoch}',
      partId: part,
      qtyDelta: q,
      reason: r,
      at: _t,
    );

void main() {
  group('partKey / matching', () {
    test('ignores case, spaces and punctuation', () {
      expect(partKey('af-123'), partKey('AF 123'));
      expect(partKey('LF 3000'), 'LF3000');
    });

    test('matches alternates', () {
      final p = part('1', 'LF3000', alts: ['P551000']);
      expect(findPartByNumber([p], 'p-551000'), p);
      expect(findPartByNumber([p], 'zzz'), isNull);
      expect(findPartByNumber([p], ''), isNull);
    });

    test('inactive parts are not matched', () {
      expect(findPartByNumber([part('1', 'A1', active: false)], 'A1'), isNull);
    });
  });

  group('searchParts', () {
    final parts = [
      part('1', 'LF3000', name: 'Oil filter', mfr: 'Fleetguard'),
      part('2', 'LF3000X', name: 'Oil filter XL', mfr: 'Fleetguard'),
      part('3', 'AF25550', name: 'Air filter', mfr: 'Donaldson'),
    ];

    test('empty query finds nothing', () {
      expect(searchParts(parts, '  '), isEmpty);
    });

    test('exact part number ranks first', () {
      expect(searchParts(parts, 'lf3000').map((p) => p.id), ['1', '2']);
    });

    test('every word must match', () {
      expect(searchParts(parts, 'oil donaldson'), isEmpty);
      expect(searchParts(parts, 'air donaldson').map((p) => p.id), ['3']);
    });

    test('finds by punctuated number', () {
      expect(searchParts(parts, 'AF-25550').map((p) => p.id), ['3']);
    });
  });

  group('stock', () {
    test('sums every on-hand reason', () {
      final p = part('1', 'A');
      final s = computeStock([p], [
        mv('1', 10, MovementReason.receive),
        mv('1', -2, MovementReason.issue),
        mv('1', 1, MovementReason.returned),
        mv('1', -1, MovementReason.adjust),
        mv('1', 3, MovementReason.count),
      ]).single;
      expect(s.onHand, 11);
      expect(s.reserved, 0);
    });

    test('reservations lower available, not on hand', () {
      final s = computeStock([part('1', 'A')], [
        mv('1', 10, MovementReason.receive),
        mv('1', 4, MovementReason.reserve),
        mv('1', 1, MovementReason.release),
      ]).single;
      expect(s.onHand, 10);
      expect(s.reserved, 3);
      expect(s.available, 7);
    });

    test('status: out, low, ok and negative', () {
      final p = part('1', 'A', min: 3);
      StockStatus st(int n) => computeStock([p],
              [if (n != 0) mv('1', n, MovementReason.adjust)]).single.status;
      expect(st(0), StockStatus.out);
      expect(st(3), StockStatus.low);
      expect(st(4), StockStatus.ok);
      final neg = computeStock([p], [mv('1', -2, MovementReason.adjust)]).single;
      expect(neg.status, StockStatus.out);
      expect(neg.needsReconciliation, isTrue);
    });

    test('no minimum means never low', () {
      final s = computeStock([part('1', 'A')], [mv('1', 1, MovementReason.receive)]).single;
      expect(s.status, StockStatus.ok);
    });

    test('filter and summary', () {
      final levels = computeStock([
        part('1', 'B1', min: 5),
        part('2', 'A2', min: 5),
        part('3', 'C3'),
        part('4', 'D4', active: false),
      ], [
        mv('1', 2, MovementReason.receive),
        mv('2', 20, MovementReason.receive),
      ]);
      expect(filterStock(levels).map((l) => l.part.id), ['2', '1', '3']);
      expect(filterStock(levels, filter: StockFilter.low).map((l) => l.part.id), ['1']);
      expect(filterStock(levels, filter: StockFilter.out).map((l) => l.part.id), ['3']);
      expect(filterStock(levels, query: 'b1').map((l) => l.part.id), ['1']);
      final s = stockSummary(levels);
      expect((s.parts, s.low, s.out), (3, 1, 1));
    });

    test('movement and part JSON round trip', () {
      final m = InventoryMovement(
          id: 'x', partId: 'p', qtyDelta: -2, reason: MovementReason.issue, at: _t, note: 'n', jobRef: 'maintenance:1');
      final back = InventoryMovement.decode(InventoryMovement.encode(m))!;
      expect(back.qtyDelta, -2);
      expect(back.reason, MovementReason.issue);
      expect(back.jobRef, 'maintenance:1');
      final p = part('1', 'A', alts: ['B']).copyWith(slot: MaterialSlot.oilFilter);
      final pb = CatalogPart.decode(CatalogPart.encode(p))!;
      expect(pb.slot, MaterialSlot.oilFilter);
      expect(pb.altPartNumbers, ['B']);
      expect(CatalogPart.decode('garbage'), isNull);
    });
  });

  group('InventoryRepository', () {
    late Box<String> catalog;
    late Box<String> ledger;
    late List<(String, String, Map<String, dynamic>)> sent;
    var n = 0;

    setUp(() async {
      Hive.init('${Directory.systemTemp.path}/inv_test_${DateTime.now().microsecondsSinceEpoch}');
      catalog = await Hive.openBox<String>('c${n++}');
      ledger = await Hive.openBox<String>('l$n');
      sent = [];
    });

    InventoryRepository repo({String? tenant = 'T', List<Map<String, dynamic>> Function(String)? remote}) =>
        InventoryRepository(
          catalogBox: catalog,
          movementsBox: ledger,
          upsert: (t, id, row) async => sent.add((t, id, row)),
          fetch: (t) async => remote?.call(t) ?? const [],
          tenantId: () => tenant,
          userId: () => 'U',
        );

    test('rejects a duplicate part number but allows editing itself', () async {
      final r = repo();
      final a = await r.savePart(r.newPart(partNumber: 'AF-1', name: 'Air'));
      await expectLater(
        r.savePart(r.newPart(partNumber: 'af 1')),
        throwsA(isA<DuplicatePartException>()),
      );
      await r.savePart(a.copyWith(name: 'Air filter'));
      expect((await r.parts()).single.name, 'Air filter');
    });

    test('receive, issue and count change stock and queue sync', () async {
      final r = repo();
      final p = await r.savePart(r.newPart(partNumber: 'X1'));
      await r.record(partId: p.id, qty: 10, reason: MovementReason.receive);
      await r.record(partId: p.id, qty: -3, reason: MovementReason.issue);
      expect((await r.stock()).single.onHand, 7);
      await r.recordCount(p.id, 5);
      expect((await r.stock()).single.onHand, 5);
      expect(await r.recordCount(p.id, 5), isNull); // no difference
      expect(sent.where((s) => s.$1 == kInventoryMovementsTable), hasLength(3));
      final row = sent.lastWhere((s) => s.$1 == kInventoryMovementsTable).$3;
      expect(row['location_id'], 'T');
      expect(row['qty_delta'], -2);
      expect(sent.any((s) => s.$1 == kInventoryLocationsTable), isTrue);
    });

    test('nothing is queued without a tenant', () async {
      final r = repo(tenant: null);
      final p = await r.savePart(r.newPart(partNumber: 'X1'));
      await r.record(partId: p.id, qty: 1, reason: MovementReason.receive);
      expect(sent, isEmpty);
      expect((await r.stock()).single.onHand, 1);
    });

    test('refreshFromCloud merges catalog by date and adds missing movements', () async {
      final seed = repo();
      final p = await seed.savePart(seed.newPart(partNumber: 'X1', name: 'Old'));
      final newer = partToRow(p.copyWith(name: 'New', updatedAt: DateTime.utc(2099)), 'T', null);
      final older = partToRow(p.copyWith(name: 'Stale', updatedAt: DateTime.utc(2000)), 'T', null);
      final mrow = movementToRow(
          InventoryMovement(id: 'm1', partId: p.id, qtyDelta: 4, reason: MovementReason.receive, at: _t), 'T');

      var r = repo(remote: (t) => t == kPartsCatalogTable ? [newer] : [mrow]);
      expect(await r.refreshFromCloud(), 2);
      expect((await r.parts()).single.name, 'New');
      expect((await r.stock()).single.onHand, 4);

      r = repo(remote: (t) => t == kPartsCatalogTable ? [older] : [mrow]);
      expect(await r.refreshFromCloud(), 0);
      expect((await r.parts()).single.name, 'New');
    });
  });
}
