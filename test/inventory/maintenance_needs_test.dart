import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/job_needs.dart';
import 'package:voltcore/modules/inventory/domain/short_jobs.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

final _t = DateTime.utc(2026);
final _lf = CatalogPart(id: '1', partNumber: 'LF3000', createdAt: _t, updatedAt: _t);

MaterialItem _item(String id, String number, {bool flagged = false, int qty = 1}) =>
    MaterialItem(id: id, slot: MaterialSlot.oilFilter, partNumber: number,
        quantity: qty, needsReplacement: flagged);

JobNeedsInput _job(MaterialOwnerType type, String id, List<MaterialItem> items,
        {bool all = false}) =>
    JobNeedsInput(type: type, id: id, title: id, items: items, allItemsNeeded: all);

InventoryMovement _receive(int q) => InventoryMovement(
    id: 'r', partId: '1', qtyDelta: q, reason: MovementReason.receive, at: _t);

void main() {
  test('an open maintenance needs every listed item with a part number', () {
    final r = computeJobNeeds([
      _job(MaterialOwnerType.maintenance, 'm1',
          [_item('a', 'LF3000', qty: 2), _item('b', 'ZZ9'), _item('c', '  ')],
          all: true),
    ], [_lf], [_receive(5)]);
    final lines = r.single.lines;
    expect(lines.map((l) => l.item.id), ['a', 'b']);
    expect(lines.first.status, NeedStatus.available);
    expect(lines.last.status, NeedStatus.notInCatalog);
    expect(r.single.job.jobRef, 'maintenance:m1');
  });

  test('without the flag only items marked for replacement count', () {
    final r = computeJobNeeds([
      _job(MaterialOwnerType.maintenance, 'm1', [_item('a', 'LF3000')]),
      _job(MaterialOwnerType.inspection, 'i1',
          [_item('a', 'LF3000', flagged: true), _item('b', 'ZZ9')]),
    ], [_lf], [_receive(5)]);
    expect(r.map((j) => j.job.id), ['i1']);
    expect(r.single.lines.length, 1);
  });

  test('maintenance needs reserve and issue under the maintenance ref', () {
    final r = computeJobNeeds([
      _job(MaterialOwnerType.maintenance, 'm1', [_item('a', 'LF3000', qty: 2)], all: true),
    ], [_lf], [
      _receive(5),
      InventoryMovement(id: 'x', partId: '1', qtyDelta: 2,
          reason: MovementReason.reserve, at: _t, jobRef: 'maintenance:m1'),
    ]);
    expect(r.single.lines.single.status, NeedStatus.reserved);
  });

  test('jobsShortOfParts counts jobs with something uncovered', () {
    final needs = computeJobNeeds([
      _job(MaterialOwnerType.maintenance, 'ok', [_item('a', 'LF3000')], all: true),
      _job(MaterialOwnerType.maintenance, 'short', [_item('b', 'ZZ9')], all: true),
      _job(MaterialOwnerType.inspection, 'partial',
          [_item('c', 'LF3000', qty: 9, flagged: true)]),
    ], [_lf], [_receive(2)]);
    expect(jobsShortOfParts(needs), 2);
    expect(jobsShortOfParts(needs.where((j) => j.job.id == 'ok')), 0);
    expect(jobsShortOfParts(const []), 0);
  });
}
