import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/job_cost.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';

int _n = 0;
InventoryMovement _m(String part, int delta, MovementReason r, String? job) =>
    InventoryMovement(
      id: 'm${_n++}',
      partId: part,
      qtyDelta: delta,
      reason: r,
      at: DateTime.utc(2026),
      jobRef: job,
    );

void main() {
  const job = 'inspection:a';

  test('issued minus returned, at the last paid price', () {
    final ledger = [
      _m('p1', -5, MovementReason.issue, job),
      _m('p1', 2, MovementReason.returned, job),
      _m('p2', -1, MovementReason.issue, job),
      _m('p1', -9, MovementReason.issue, 'inspection:other'),
    ];
    final c = computeJobCost(job, ledger, {'p1': 1000, 'p2': 250});
    expect(c.parts, 2);
    expect(c.totalCents, 3 * 1000 + 250);
    expect(c.unpricedParts, 0);
    expect(c.lines.firstWhere((l) => l.partId == 'p1').qty, 3);
  });

  test('a part with no paid price is counted as unpriced and adds nothing', () {
    final ledger = [
      _m('p1', -2, MovementReason.issue, job),
      _m('p2', -4, MovementReason.issue, job),
    ];
    final c = computeJobCost(job, ledger, {'p1': 500});
    expect(c.totalCents, 1000);
    expect(c.unpricedParts, 1);
    expect(c.lines.firstWhere((l) => l.partId == 'p2').priced, isFalse);
  });

  test('more returned than issued clamps to zero and drops the part', () {
    final ledger = [
      _m('p1', -1, MovementReason.issue, job),
      _m('p1', 3, MovementReason.returned, job),
    ];
    final c = computeJobCost(job, ledger, {'p1': 500});
    expect(c.isEmpty, isTrue);
    expect(c.totalCents, 0);
  });

  test('fully returned parts and reservations cost nothing', () {
    final ledger = [
      _m('p1', -2, MovementReason.issue, job),
      _m('p1', 2, MovementReason.returned, job),
      _m('p2', 3, MovementReason.reserve, job),
      _m('p3', 5, MovementReason.receive, null),
    ];
    expect(computeJobCost(job, ledger, {'p1': 1, 'p2': 1, 'p3': 1}).isEmpty,
        isTrue);
  });

  test('an unknown job has no cost', () {
    expect(computeJobCost('maintenance:x', const [], const {}).isEmpty, isTrue);
  });

  test('computeJobCosts splits the ledger by job', () {
    final ledger = [
      _m('p1', -1, MovementReason.issue, 'inspection:a'),
      _m('p1', -2, MovementReason.issue, 'maintenance:b'),
    ];
    final all = computeJobCosts(ledger, {'p1': 100});
    expect(all['inspection:a']!.totalCents, 100);
    expect(all['maintenance:b']!.totalCents, 200);
    expect(all.length, 2);
  });
}
