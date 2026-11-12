import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/material_usage.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';

final _t = DateTime.utc(2026, 1, 1);

CatalogPart _part(String id, String number) => CatalogPart(
    id: id, partNumber: number, createdAt: _t, updatedAt: _t);

InventoryMovement _mv(String id, String part, int q, MovementReason r,
        {String loc = kMainLocationId}) =>
    InventoryMovement(
        id: id, partId: part, qtyDelta: q, reason: r, at: _t, locationId: loc);

int _total(List<StockLevel> l, String part) =>
    l.firstWhere((x) => x.part.id == part).onHand;

void main() {
  group('transfer arithmetic', () {
    final parts = [_part('p', 'AF-1'), _part('q', 'OF-2')];

    test('company total is unchanged, per location is correct', () {
      final moves = [
        _mv('1', 'p', 10, MovementReason.receive),
        _mv('2', 'q', 4, MovementReason.receive),
        _mv('3', 'p', -3, MovementReason.transfer),
        _mv('4', 'p', 3, MovementReason.transfer, loc: 'truck'),
      ];
      expect(_total(computeStock(parts, moves), 'p'), 10);
      expect(_total(computeStockAt(parts, moves, kMainLocationId), 'p'), 7);
      expect(_total(computeStockAt(parts, moves, 'truck'), 'p'), 3);
      expect(_total(computeStockAt(parts, moves, 'truck'), 'q'), 0);
      expect(onHandAt(moves, 'p', 'truck'), 3);
      expect(onHandAt(moves, 'p', kMainLocationId), 7);
    });

    test('reserved never moves with a transfer', () {
      final moves = [
        _mv('1', 'p', 10, MovementReason.receive),
        _mv('2', 'p', 2, MovementReason.reserve),
        _mv('3', 'p', -4, MovementReason.transfer),
        _mv('4', 'p', 4, MovementReason.transfer, loc: 'truck'),
      ];
      final l = computeStock(parts, moves).first;
      expect(l.onHand, 10);
      expect(l.reserved, 2);
    });

    test('a round trip nets to zero everywhere', () {
      final moves = [
        _mv('1', 'p', 5, MovementReason.receive),
        _mv('2', 'p', -2, MovementReason.transfer),
        _mv('3', 'p', 2, MovementReason.transfer, loc: 'truck'),
        _mv('4', 'p', -2, MovementReason.transfer, loc: 'truck'),
        _mv('5', 'p', 2, MovementReason.transfer),
      ];
      expect(onHandAt(moves, 'p', 'truck'), 0);
      expect(onHandAt(moves, 'p', kMainLocationId), 5);
    });

    test('transferProblem blocks bad requests', () {
      String? p(String from, String to, int qty, int have) => transferProblem(
          fromId: from, toId: to, qty: qty, onHandAtSource: have);
      expect(p('a', 'a', 1, 5), isNotNull);
      expect(p('a', 'b', 0, 5), isNotNull);
      expect(p('a', 'b', -1, 5), isNotNull);
      expect(p('a', 'b', 6, 5), contains('Only 5'));
      expect(p('a', 'b', 1, 0), contains('Nothing on hand'));
      expect(p('a', 'b', 5, 5), isNull);
    });

    test('planTransfer makes a negative and a positive line', () {
      final plan = planTransfer(
        partId: 'p',
        fromId: 'a',
        toId: 'b',
        qty: 3,
        onHandAtSource: 3,
        at: _t,
        outId: 'o',
        intoId: 'i',
      );
      expect(plan.out.qtyDelta, -3);
      expect(plan.out.locationId, 'a');
      expect(plan.into.qtyDelta, 3);
      expect(plan.into.locationId, 'b');
      expect(plan.out.reason, MovementReason.transfer);
      expect(
        () => planTransfer(
            partId: 'p',
            fromId: 'a',
            toId: 'b',
            qty: 4,
            onHandAtSource: 3,
            at: _t,
            outId: 'o',
            intoId: 'i'),
        throwsArgumentError,
      );
    });

    test('transfer wire round-trips and counts as on hand', () {
      expect(MovementReason.fromWire('transfer'), MovementReason.transfer);
      expect(MovementReason.transfer.changesOnHand, isTrue);
    });
  });

  group('row mapping', () {
    test('main maps to the tenant id and back; trucks keep their id', () {
      final main = _mv('1', 'p', 1, MovementReason.receive);
      final truck = _mv('2', 'p', 1, MovementReason.transfer, loc: 'truck-9');
      final r1 = movementToRow(main, 'T');
      final r2 = movementToRow(truck, 'T');
      expect(r1['location_id'], 'T');
      expect(r2['location_id'], 'truck-9');
      expect(movementFromRow(r1)!.locationId, kMainLocationId);
      expect(movementFromRow(r2)!.locationId, 'truck-9');
      expect(movementFromRow(r2)!.reason, MovementReason.transfer);
    });

    test('locations map to rows; the warehouse row is skipped', () {
      final truck = InventoryLocation(
          id: 'x',
          name: 'Truck A',
          vehicleId: 'v1',
          assignedUserId: 'u1',
          updatedAt: _t);
      final row = locationToRow(truck, 'T');
      expect(row['kind'], 'truck');
      expect(row['vehicle_id'], 'v1');
      expect(row['assigned_user_id'], 'u1');
      final back = locationFromRow(row)!;
      expect(back.name, 'Truck A');
      expect(back.vehicleId, 'v1');
      expect(locationFromRow({'id': 'T', 'tenant_id': 'T', 'name': 'Main'}),
          isNull);
    });
  });

  group('repository', () {
    late Box<String> catalog, ledger, locs;
    late List<(String, String, Map<String, dynamic>)> sent;
    var n = 0;
    var ids = 0;

    setUp(() async {
      Hive.init(
          '${Directory.systemTemp.path}/truck_test_${DateTime.now().microsecondsSinceEpoch}');
      n++;
      catalog = await Hive.openBox<String>('c$n');
      ledger = await Hive.openBox<String>('l$n');
      locs = await Hive.openBox<String>('x$n');
      sent = [];
      ids = 0;
    });

    InventoryRepository repo({String user = 'U'}) => InventoryRepository(
          catalogBox: catalog,
          movementsBox: ledger,
          locationsBox: locs,
          upsert: (t, id, row) async => sent.add((t, id, row)),
          fetch: (t) async => const [],
          tenantId: () => 'T',
          userId: () => user,
          newId: () => 'id${ids++}',
        );

    test('trucks can be added, renamed and deactivated', () async {
      final r = repo();
      expect((await r.locations()).map((l) => l.name), ['Main warehouse']);
      final t = await r.saveLocation(r.newTruck(name: ' Truck B '));
      await r.saveLocation(r.newTruck(name: 'Truck A', vehicleId: 'v'));
      expect((await r.locations()).map((l) => l.name),
          ['Main warehouse', 'Truck A', 'Truck B']);
      await r.saveLocation(t.copyWith(name: 'Truck C', isActive: false));
      expect((await r.locations()).map((l) => l.name),
          ['Main warehouse', 'Truck A']);
      expect(
          (await r.locations(includeInactive: true)).map((l) => l.name),
          contains('Truck C'));
      expect(sent.where((s) => s.$1 == kInventoryLocationsTable), isNotEmpty);
      await expectLater(
          r.saveLocation(r.newTruck(name: '  ')), throwsArgumentError);
    });

    test('transfer writes two ledger rows and blocks overdrafts', () async {
      final r = repo();
      final p = await r.savePart(r.newPart(partNumber: 'X1'));
      final truck = await r.saveLocation(r.newTruck(name: 'Truck A'));
      await r.record(partId: p.id, qty: 10, reason: MovementReason.receive);

      await r.transfer(
          partId: p.id, fromId: kMainLocationId, toId: truck.id, qty: 4);
      expect((await r.stock()).single.onHand, 10);
      expect((await r.stockAt(kMainLocationId)).single.onHand, 6);
      expect((await r.stockAt(truck.id)).single.onHand, 4);

      // Rows reach the cloud with the right location ids.
      final rows = sent
          .where((s) => s.$1 == kInventoryMovementsTable)
          .map((s) => s.$3)
          .where((m) => m['reason'] == 'transfer')
          .toList();
      expect(rows.map((m) => m['qty_delta']), [-4, 4]);
      expect(rows.map((m) => m['location_id']), ['T', truck.id]);

      await expectLater(
          r.transfer(
              partId: p.id, fromId: truck.id, toId: kMainLocationId, qty: 5),
          throwsArgumentError);
      await expectLater(
          r.transfer(
              partId: p.id, fromId: kMainLocationId, toId: truck.id, qty: 7),
          throwsArgumentError);
      expect((await r.stockAt(truck.id)).single.onHand, 4);
    });

    group('mark used', () {
      const owner = MaterialOwner.maintenance(id: 'm1');
      MaterialItem item({String pn = 'X1', int qty = 2, DateTime? date}) =>
          MaterialItem(
              id: 'it',
              slot: MaterialSlot.airFilter,
              partNumber: pn,
              quantity: qty,
              dateUsed: date);

      test('issues once, against the warehouse, and sets the date', () async {
        final r = repo();
        final p = await r.savePart(r.newPart(partNumber: 'X1'));
        await r.record(partId: p.id, qty: 5, reason: MovementReason.receive);
        final svc = MaterialUsageService(r,
            userId: () => 'U', today: () => DateTime(2026, 3, 4, 15));

        final first = await svc.markUsed(owner, item());
        expect(first.outcome, UsageOutcome.issued);
        expect(first.item.dateUsed, DateTime(2026, 3, 4));
        expect(first.item.usedMovementId, isNotNull);
        expect((await r.stock()).single.onHand, 3);
        final m = await r.movementById(first.item.usedMovementId!);
        expect(m!.reason, MovementReason.issue);
        expect(m.jobRef, 'maintenance:m1');
        expect(m.qtyDelta, -2);

        // Idempotent.
        final again = await svc.markUsed(owner, first.item);
        expect(again.outcome, UsageOutcome.alreadyUsed);
        expect((await r.stock()).single.onHand, 3);

        // Undo returns it at the same place, once.
        final undone = await svc.undoUsed(owner, first.item);
        expect(undone.outcome, UsageOutcome.returned);
        expect(undone.item.usedMovementId, isNull);
        expect((await r.stock()).single.onHand, 5);
      });

      test('keeps a date that is already set', () async {
        final r = repo();
        final p = await r.savePart(r.newPart(partNumber: 'X1'));
        await r.record(partId: p.id, qty: 5, reason: MovementReason.receive);
        final svc = MaterialUsageService(r, userId: () => 'U');
        final res = await svc.markUsed(owner, item(date: DateTime(2026, 1, 2)));
        expect(res.item.dateUsed, DateTime(2026, 1, 2));
      });

      test('uses the technician\'s own truck when it has enough', () async {
        final r = repo();
        final p = await r.savePart(r.newPart(partNumber: 'X1'));
        final mine = await r.saveLocation(
            r.newTruck(name: 'Mine', assignedUserId: 'U'));
        final other = await r.saveLocation(
            r.newTruck(name: 'Other', assignedUserId: 'Z'));
        await r.record(partId: p.id, qty: 10, reason: MovementReason.receive);
        await r.transfer(
            partId: p.id, fromId: kMainLocationId, toId: mine.id, qty: 3);
        await r.transfer(
            partId: p.id, fromId: kMainLocationId, toId: other.id, qty: 5);
        final svc = MaterialUsageService(r, userId: () => 'U');

        final res = await svc.markUsed(owner, item(qty: 2));
        expect(res.locationName, 'Mine');
        expect((await r.stockAt(mine.id)).single.onHand, 1);
        expect((await r.stockAt(other.id)).single.onHand, 5);
        expect((await r.stockAt(kMainLocationId)).single.onHand, 2);

        // Undo goes back to the truck it came from.
        await svc.undoUsed(owner, res.item);
        expect((await r.stockAt(mine.id)).single.onHand, 3);
      });

      test('falls back to the warehouse when the truck is short', () async {
        final r = repo();
        final p = await r.savePart(r.newPart(partNumber: 'X1'));
        final mine = await r.saveLocation(
            r.newTruck(name: 'Mine', assignedUserId: 'U'));
        await r.record(partId: p.id, qty: 10, reason: MovementReason.receive);
        await r.transfer(
            partId: p.id, fromId: kMainLocationId, toId: mine.id, qty: 1);
        final svc = MaterialUsageService(r, userId: () => 'U');
        final res = await svc.markUsed(owner, item(qty: 2));
        expect(res.locationName, 'Main warehouse');
        expect((await r.stockAt(mine.id)).single.onHand, 1);
      });

      test('a part outside the catalog only records the date', () async {
        final r = repo();
        final svc = MaterialUsageService(r,
            userId: () => 'U', today: () => DateTime(2026, 3, 4));
        final res = await svc.markUsed(owner, item(pn: 'NOPE'));
        expect(res.outcome, UsageOutcome.dateOnly);
        expect(res.item.usedMovementId, isNull);
        expect(res.item.dateUsed, DateTime(2026, 3, 4));
        expect(await r.movements(), isEmpty);
        expect(res.message, contains('not in the parts catalog'));
      });

      test('inspections use the inspection job ref', () async {
        final r = repo();
        final p = await r.savePart(r.newPart(partNumber: 'X1'));
        await r.record(partId: p.id, qty: 5, reason: MovementReason.receive);
        final svc = MaterialUsageService(r, userId: () => 'U');
        final res = await svc.markUsed(
            const MaterialOwner.inspection(id: 'i9'), item());
        final m = await r.movementById(res.item.usedMovementId!);
        expect(m!.jobRef, 'inspection:i9');
      });
    });
  });

  group('MaterialItem.usedMovementId', () {
    test('old JSON loads without it and it round-trips', () {
      final old = MaterialItem.fromJson({'id': 'a', 'slot': 'air_filter'})!;
      expect(old.usedMovementId, isNull);
      expect(old.toJson().containsKey('usedMovementId'), isFalse);
      final used = old.copyWith(usedMovementId: 'm1');
      expect(MaterialItem.fromJson(used.toJson())!.usedMovementId, 'm1');
      expect(used.copyWith(usedMovementId: null).usedMovementId, isNull);
      expect(used.copyWith(notes: 'x').usedMovementId, 'm1');
    });

    test('cloud row carries the movement id and status', () {
      const owner = MaterialOwner.maintenance(id: 'm1');
      final used = MaterialItem(
          id: 'a',
          slot: MaterialSlot.airFilter,
          partNumber: 'X',
          usedMovementId: 'mv');
      final row = materialItemToRow(used, 'T', owner, sortOrder: 0);
      expect(row['used_movement_id'], 'mv');
      expect(row['status'], 'used');
      final plain = materialItemToRow(
          used.copyWith(usedMovementId: null), 'T', owner,
          sortOrder: 0);
      expect(plain['used_movement_id'], isNull);
      expect(plain['status'], 'listed');
    });
  });
}
