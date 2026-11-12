import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/usage_report.dart';

final _t = DateTime.utc(2026);
CatalogPart _part(String id, String number, String maker) => CatalogPart(
    id: id, partNumber: number, name: 'Name $number', manufacturer: maker,
    createdAt: _t, updatedAt: _t);

var _n = 0;
InventoryMovement _mv(String part, int q, MovementReason r, DateTime at, {String? job}) =>
    InventoryMovement(id: 'm${_n++}', partId: part, qtyDelta: q, reason: r, at: at, jobRef: job);

void main() {
  final parts = [_part('a', 'LF3000', 'Fleetguard'), _part('b', 'AF25', 'Donaldson'), _part('c', 'X1', '')];
  final ledger = [
    _mv('a', 10, MovementReason.receive, DateTime(2026, 1, 2)),
    _mv('a', -3, MovementReason.issue, DateTime(2026, 5, 3), job: 'inspection:i1'),
    _mv('a', -2, MovementReason.issue, DateTime(2026, 6, 3), job: 'maintenance:m1'),
    _mv('a', 1, MovementReason.returned, DateTime(2026, 6, 4), job: 'maintenance:m1'),
    _mv('b', -4, MovementReason.issue, DateTime(2026, 6, 5), job: 'inspection:i2'),
    _mv('c', -1, MovementReason.issue, DateTime(2026, 6, 6)),
    _mv('b', -9, MovementReason.adjust, DateTime(2026, 6, 6)),
    _mv('a', -1, MovementReason.reserve, DateTime(2026, 6, 6)),
  ];
  const gens = {
    'inspection:i1': UsageGenerator(key: 'g1', label: 'Generac RG048'),
    'maintenance:m1': UsageGenerator(key: 'g1', label: 'Generac RG048'),
    'inspection:i2': UsageGenerator(key: 'g2', label: 'Kohler 20'),
  };

  test('issued net of returns; receipts, adjustments and reservations ignored', () {
    final r = computeUsageReport(ledger, parts, generatorOf: gens);
    expect(r.totalQty, 3 + 2 - 1 + 4 + 1);
    expect(r.byPart.map((x) => '${x.label}:${x.qty}'), ['AF25:4', 'LF3000:4', 'X1:1']);
    expect(r.totalCostCents, isNull);
    expect(r.byPart.first.costCents, isNull);
  });

  test('by manufacturer, with unknown for none', () {
    final r = computeUsageReport(ledger, parts, generatorOf: gens);
    expect({for (final x in r.byManufacturer) x.label: x.qty},
        {'Fleetguard': 4, 'Donaldson': 4, 'Unknown': 1});
  });

  test('by month, oldest first', () {
    final r = computeUsageReport(ledger, parts, generatorOf: gens);
    expect(r.byMonth.map((x) => '${x.key}:${x.qty}'), ['2026-05:3', '2026-06:6']);
  });

  test('by generator through the job ref, with jobs counted and the rest apart', () {
    final r = computeUsageReport(ledger, parts, generatorOf: gens);
    final g1 = r.byGenerator.firstWhere((x) => x.key == 'g1');
    expect(g1.qty, 4);
    expect(g1.jobs, 2);
    expect(g1.label, 'Generac RG048');
    expect(r.byGenerator.firstWhere((x) => x.key == 'g2').qty, 4);
    expect(r.noGeneratorQty, 1);
  });

  test('period bounds', () {
    final r = computeUsageReport(ledger, parts,
        from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 6), generatorOf: gens);
    expect(r.totalQty, 2 - 1 + 4);
    expect(r.byMonth.single.key, '2026-06');
    final none = computeUsageReport(ledger, parts, from: DateTime(2027));
    expect(none.isEmpty, isTrue);
    expect(none.totalQty, 0);
  });

  test('cost is quantity times last price paid, and unpriced parts are counted', () {
    final r = computeUsageReport(ledger, parts,
        generatorOf: gens, lastPaidCents: {'a': 1000, 'b': 250});
    expect(r.totalCostCents, 4 * 1000 + 4 * 250);
    expect(r.unpricedParts, 1);
    expect(r.byPart.firstWhere((x) => x.label == 'LF3000').costCents, 4000);
    expect(r.byPart.firstWhere((x) => x.label == 'X1').costCents, isNull);
  });

  test('csv has the breakdowns, escapes commas and quotes, and costs only when asked', () {
    final p = [_part('a', 'LF,3000', 'Fleet "guard"')];
    final m = [_mv('a', -2, MovementReason.issue, DateTime(2026, 6, 3))];
    final plain = usageReportCsv(computeUsageReport(m, p));
    final lines = plain.trim().split('\r\n');
    expect(lines.first, 'Breakdown,Name,Detail,Qty issued');
    expect(lines, contains('Part,"LF,3000","Name LF,3000 · Fleet ""guard""",2'));
    expect(lines, contains('Manufacturer,"Fleet ""guard""",,2'));
    expect(lines, contains('Month,2026-06,,2'));
    expect(lines.last, 'Total,,,2');

    final priced = usageReportCsv(computeUsageReport(m, p, lastPaidCents: {'a': 1050}));
    expect(priced.split('\r\n').first, 'Breakdown,Name,Detail,Qty issued,Cost');
    expect(priced.trim().split('\r\n').last, 'Total,,,2,21.00');
  });
}
