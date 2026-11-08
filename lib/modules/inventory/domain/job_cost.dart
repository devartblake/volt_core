import 'package:flutter/foundation.dart';

import 'stock.dart';

/// One part's share of a job's cost.
@immutable
class JobPartCost {
  const JobPartCost({
    required this.partId,
    required this.qty,
    this.unitCents,
  });

  final String partId;

  /// Issued less returned; always above zero.
  final int qty;

  /// The last price paid for one, or null when no price is on record.
  final int? unitCents;

  bool get priced => unitCents != null;

  /// Zero when unpriced.
  int get lineCents => (unitCents ?? 0) * qty;
}

/// What the parts issued to one job cost.
@immutable
class JobCost {
  const JobCost(this.lines);

  static const JobCost empty = JobCost([]);

  final List<JobPartCost> lines;

  /// How many different parts were used.
  int get parts => lines.length;

  /// Sum of the priced lines. Understated when [unpricedParts] is above zero.
  int get totalCents => lines.fold(0, (s, l) => s + l.lineCents);

  int get unpricedParts => lines.where((l) => !l.priced).length;

  bool get isEmpty => lines.isEmpty;
}

/// Net quantity per part for each job: issued less returned. Only `issue` and
/// `return` movements with a job reference count (a reservation moves no
/// stock). A part whose returns exceed its issues counts as zero, never
/// negative.
Map<String, Map<String, int>> _netByJob(Iterable<InventoryMovement> ledger) {
  final out = <String, Map<String, int>>{};
  for (final m in ledger) {
    final ref = m.jobRef;
    if (ref == null || ref.isEmpty) continue;
    // The ledger stores an issue as a negative and a return as a positive, so
    // what is out on the job is the negated sum of both.
    if (m.reason != MovementReason.issue &&
        m.reason != MovementReason.returned) {
      continue;
    }
    final delta = -m.qtyDelta;
    final parts = out.putIfAbsent(ref, () => {});
    parts[m.partId] = (parts[m.partId] ?? 0) + delta;
  }
  return out;
}

JobCost _build(Map<String, int> net, Map<String, int> lastPaidByPart) {
  final lines = <JobPartCost>[
    for (final e in net.entries)
      if (e.value > 0)
        JobPartCost(
            partId: e.key, qty: e.value, unitCents: lastPaidByPart[e.key]),
  ]..sort((a, b) => a.partId.compareTo(b.partId));
  return JobCost(lines);
}

/// The parts cost of one job from the ledger, each part at the last price
/// paid ([lastPaidByPart], part id to cents). Matches `job_parts_cost()` on
/// the server.
JobCost computeJobCost(
  String jobRef,
  Iterable<InventoryMovement> ledger,
  Map<String, int> lastPaidByPart,
) {
  final net = _netByJob(ledger.where((m) => m.jobRef == jobRef))[jobRef];
  return net == null ? JobCost.empty : _build(net, lastPaidByPart);
}

/// The parts cost of every job that has issues, by job reference. One pass
/// over the ledger.
Map<String, JobCost> computeJobCosts(
  Iterable<InventoryMovement> ledger,
  Map<String, int> lastPaidByPart,
) {
  return {
    for (final e in _netByJob(ledger).entries)
      if (_build(e.value, lastPaidByPart) case final c when !c.isEmpty) e.key: c,
  };
}
