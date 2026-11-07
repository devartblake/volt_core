import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/job_needs.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

final _t = DateTime.utc(2026, 1, 1);

CatalogPart part(String id, String number,
        {String name = '', int min = 0, List<String> alts = const []}) =>
    CatalogPart(
        id: id, partNumber: number, name: name, minStock: min,
        altPartNumbers: alts, createdAt: _t, updatedAt: _t);

var _n = 0;
InventoryMovement mv(String part, int q, MovementReason r, {String? job}) =>
    InventoryMovement(
        id: 'm${_n++}', partId: part, qtyDelta: q, reason: r, at: _t, jobRef: job);

MaterialItem need(String number, {int qty = 1, bool flagged = true}) => MaterialItem(
    id: 'i${_n++}', slot: MaterialSlot.oilFilter, partNumber: number,
    quantity: qty, needsReplacement: flagged);

JobNeedsInput job(String id, List<MaterialItem> items, {DateTime? date}) =>
    JobNeedsInput(type: MaterialOwnerType.inspection, id: id, title: 'Job $id', date: date, items: items);

void main() {
  final lf = part('1', 'LF3000', alts: ['P551000']);

  group('computeJobNeeds', () {
    test('only flagged items are needs; jobs with none are left out', () {
      final r = computeJobNeeds(
          [job('a', [need('LF3000', flagged: false)]), job('b', [need('LF3000')])],
          [lf], [mv('1', 5, MovementReason.receive)]);
      expect(r.map((j) => j.job.id), ['b']);
    });

    test('available, partial and short against the shelf', () {
      NeedStatus st(int onHand, int qty) => computeJobNeeds(
              [job('a', [need('LF3000', qty: qty)])],
              [lf],
              [if (onHand > 0) mv('1', onHand, MovementReason.receive)])
          .single
          .lines
          .single
          .status;
      expect(st(4, 4), NeedStatus.available);
      expect(st(2, 4), NeedStatus.partial);
      expect(st(0, 1), NeedStatus.short);
    });

    test('reservations for other jobs reduce what is available', () {
      final r = computeJobNeeds([
        job('a', [need('LF3000', qty: 3)])
      ], [
        lf
      ], [
        mv('1', 4, MovementReason.receive),
        mv('1', 3, MovementReason.reserve, job: 'inspection:other'),
      ]).single.lines.single;
      expect(r.status, NeedStatus.partial);
      expect(r.available, 1);
      expect(r.shortBy, 2);
    });

    test('reserved and issued for the job itself', () {
      final base = [mv('1', 5, MovementReason.receive)];
      var l = computeJobNeeds([job('a', [need('LF3000', qty: 2)])], [lf],
          [...base, mv('1', 2, MovementReason.reserve, job: 'inspection:a')])
          .single.lines.single;
      expect(l.status, NeedStatus.reserved);
      expect(l.outstanding, 0);

      l = computeJobNeeds([job('a', [need('LF3000', qty: 2)])], [lf], [
        ...base,
        mv('1', 2, MovementReason.reserve, job: 'inspection:a'),
        mv('1', -2, MovementReason.issue, job: 'inspection:a'),
        mv('1', 2, MovementReason.release, job: 'inspection:a'),
      ]).single.lines.single;
      expect(l.status, NeedStatus.issued);
      expect(l.issued, 2);

      // One returned: only one still out, so it is no longer fully issued.
      l = computeJobNeeds([job('a', [need('LF3000', qty: 2)])], [lf], [
        ...base,
        mv('1', -2, MovementReason.issue, job: 'inspection:a'),
        mv('1', 1, MovementReason.returned, job: 'inspection:a'),
      ]).single.lines.single;
      expect(l.issued, 1);
      expect(l.status, NeedStatus.available);
    });

    test('an alternate part number resolves to the catalog part', () {
      final l = computeJobNeeds([job('a', [need('p-551000')])], [lf],
          [mv('1', 1, MovementReason.receive)]).single.lines.single;
      expect(l.part?.id, '1');
      expect(l.usingAlternate, isTrue);
      expect(l.status, NeedStatus.available);
    });

    test('a number not in the catalog is flagged', () {
      final l = computeJobNeeds([job('a', [need('ZZZ')])], [lf], []).single.lines.single;
      expect(l.status, NeedStatus.notInCatalog);
    });

    test('soonest job first, undated last', () {
      final r = computeJobNeeds([
        job('c', [need('LF3000')]),
        job('b', [need('LF3000')], date: DateTime.utc(2026, 5, 1)),
        job('a', [need('LF3000')], date: DateTime.utc(2026, 2, 1)),
      ], [lf], []);
      expect(r.map((j) => j.job.id), ['a', 'b', 'c']);
    });
  });

  group('shortages', () {
    test('adds up across jobs, ignores covered lines, lists uncatalogued', () {
      final needs = computeJobNeeds([
        job('a', [need('LF3000', qty: 2)]),
        job('b', [need('LF3000', qty: 3), need('ZZZ', qty: 1)]),
        job('c', [need('LF3000', qty: 1)]),
      ], [lf], [
        mv('1', 2, MovementReason.receive),
        mv('1', 1, MovementReason.reserve, job: 'inspection:c'),
      ]);
      final s = computeShortages(needs);
      final lfShort = s.firstWhere((x) => x.part?.id == '1');
      // a needs 2, b needs 3, c is covered; 1 available (2 on hand, 1 reserved).
      expect(lfShort.needed, 5);
      expect(lfShort.available, 1);
      expect(lfShort.shortBy, 4);
      expect(lfShort.jobs, 2);
      expect(s.any((x) => x.part == null && x.partNumber == 'ZZZ'), isTrue);
    });

    test('nothing short means an empty list', () {
      final needs = computeJobNeeds([job('a', [need('LF3000')])], [lf],
          [mv('1', 9, MovementReason.receive)]);
      expect(computeShortages(needs), isEmpty);
    });
  });

  test('lowStockParts lists parts at or under their minimum, lowest first', () {
    final levels = computeStock([
      part('1', 'A', min: 5),
      part('2', 'B', min: 5),
      part('3', 'C'),
    ], [
      mv('1', 5, MovementReason.receive),
      mv('2', 10, MovementReason.receive),
      mv('2', 8, MovementReason.reserve),
    ]);
    expect(lowStockParts(levels).map((l) => l.part.id), ['2', '1']);
  });
}
