import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/movement_log.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

final _t = DateTime.utc(2026);
CatalogPart _part(String id, String number, {String name = '', String maker = ''}) =>
    CatalogPart(
        id: id, partNumber: number, name: name, manufacturer: maker,
        createdAt: _t, updatedAt: _t);

var _n = 0;
InventoryMovement _mv(String part, int q, MovementReason r, DateTime at,
        {String? job, String? user}) =>
    InventoryMovement(
        id: 'm${_n++}', partId: part, qtyDelta: q, reason: r, at: at,
        jobRef: job, userId: user);

void main() {
  final now = DateTime(2026, 6, 15, 12);
  final parts = {
    'a': _part('a', 'LF-3000', name: 'Oil filter', maker: 'Fleetguard'),
    'b': _part('b', 'AF25550', name: 'Air filter', maker: 'Donaldson'),
  };
  final ledger = [
    _mv('a', 5, MovementReason.receive, DateTime(2026, 6, 15, 9)),
    _mv('a', -2, MovementReason.issue, DateTime(2026, 6, 15, 10), job: 'inspection:x'),
    _mv('b', 3, MovementReason.receive, DateTime(2026, 6, 10, 8)),
    _mv('b', -1, MovementReason.adjust, DateTime(2026, 5, 20, 8)),
    _mv('a', 1, MovementReason.returned, DateTime(2026, 3, 1, 8)),
  ];

  group('filterMovements', () {
    List<InventoryMovement> f({
      Set<MovementReason> reasons = const {},
      MovementPeriod period = MovementPeriod.all,
      String query = '',
    }) =>
        filterMovements(ledger, parts: parts, reasons: reasons, period: period, query: query, now: now);

    test('newest first, everything by default', () {
      final r = f();
      expect(r.length, 5);
      expect(r.first.at, DateTime(2026, 6, 15, 10));
      expect(r.last.at, DateTime(2026, 3, 1, 8));
    });

    test('reason chips combine as "any of"', () {
      expect(f(reasons: {MovementReason.receive}).length, 2);
      expect(f(reasons: {MovementReason.receive, MovementReason.issue}).length, 3);
    });

    test('periods', () {
      expect(f(period: MovementPeriod.today).length, 2);
      expect(f(period: MovementPeriod.week).length, 3);
      expect(f(period: MovementPeriod.month).length, 4);
      expect(f(period: MovementPeriod.all).length, 5);
    });

    test('part search by number (ignoring punctuation), name and maker', () {
      expect(f(query: 'lf3000').map((m) => m.partId).toSet(), {'a'});
      expect(f(query: 'air').map((m) => m.partId).toSet(), {'b'});
      expect(f(query: 'fleet').length, 3);
      expect(f(query: 'nothing'), isEmpty);
    });

    test('filters combine', () {
      expect(f(reasons: {MovementReason.receive}, period: MovementPeriod.today, query: 'LF').length, 1);
    });
  });

  test('groupMovementsByDay splits by local day, newest day first', () {
    final days = groupMovementsByDay(filterMovements(ledger, parts: parts, now: now));
    expect(days.map((d) => d.day), [
      DateTime(2026, 6, 15),
      DateTime(2026, 6, 10),
      DateTime(2026, 5, 20),
      DateTime(2026, 3, 1),
    ]);
    expect(days.first.movements.length, 2);
    expect(groupMovementsByDay(const []), isEmpty);
  });

  test('parseJobRef reads inspection and maintenance refs only', () {
    final i = parseJobRef('inspection:abc-1')!;
    expect(i.type, MaterialOwnerType.inspection);
    expect(i.id, 'abc-1');
    expect(parseJobRef('maintenance:9')!.type, MaterialOwnerType.maintenance);
    expect(parseJobRef('workorder:1'), isNull);
    expect(parseJobRef('inspection:'), isNull);
    expect(parseJobRef('nonsense'), isNull);
    expect(parseJobRef(null), isNull);
  });

  test('movementUserLabel uses the name, else a short id', () {
    expect(movementUserLabel('u1', {'u1': 'Dana'}), 'Dana');
    expect(movementUserLabel('1234567890', const {}), '123456');
    expect(movementUserLabel('ab', const {}), 'ab');
    expect(movementUserLabel(null, const {}), '-');
  });
}
