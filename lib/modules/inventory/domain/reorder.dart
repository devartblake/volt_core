import 'package:flutter/foundation.dart';

import 'catalog_part.dart';
import 'job_needs.dart';
import 'stock.dart';
import 'vendor.dart';

/// One thing to order, with what is already on order netted off.
@immutable
class ReorderLine {
  const ReorderLine({
    required this.part,
    required this.wanted,
    required this.onOrder,
    required this.forJobs,
    required this.belowMin,
  });

  final CatalogPart part;

  /// Quantity needed before counting open orders.
  final int wanted;

  /// Quantity still to arrive on sent / partly received orders.
  final int onOrder;
  final bool forJobs;
  final bool belowMin;

  /// What to order now.
  int get orderQty {
    final n = wanted - onOrder;
    return n < 0 ? 0 : n;
  }

  bool get coveredByOrder => wanted > 0 && orderQty == 0;
}

/// Net quantity to order for a shortage: shortBy minus what is on order.
int shortageOrderQty(Shortage s, Map<String, int> onOrder) {
  final id = s.part?.id;
  final n = s.shortBy - (id == null ? 0 : (onOrder[id] ?? 0));
  return n < 0 ? 0 : n;
}

/// Quantity to bring a low part back to its minimum (at least 1).
int lowStockWanted(StockLevel l) {
  final n = l.part.minStock - l.available;
  return n < 1 ? 1 : n;
}

/// Combines job shortages and low stock into one line per catalog part, minus
/// open orders. A part both short for jobs and low gets the larger quantity.
/// Parts outside the catalog cannot be ordered here and are left out.
List<ReorderLine> buildReorderLines(
  List<Shortage> shortages,
  List<StockLevel> low,
  Map<String, int> onOrder,
) {
  final wanted = <String, int>{};
  final parts = <String, CatalogPart>{};
  final jobs = <String>{};
  final mins = <String>{};
  for (final s in shortages) {
    final p = s.part;
    if (p == null || s.shortBy <= 0) continue;
    parts[p.id] = p;
    jobs.add(p.id);
    wanted[p.id] = s.shortBy;
  }
  for (final l in low) {
    final p = l.part;
    parts[p.id] = p;
    mins.add(p.id);
    final w = lowStockWanted(l);
    final prev = wanted[p.id];
    wanted[p.id] = prev == null || w > prev ? w : prev;
  }
  return [
    for (final id in parts.keys)
      ReorderLine(
        part: parts[id]!,
        wanted: wanted[id]!,
        onOrder: onOrder[id] ?? 0,
        forJobs: jobs.contains(id),
        belowMin: mins.contains(id),
      ),
  ]..sort((a, b) =>
      partKey(a.part.partNumber).compareTo(partKey(b.part.partNumber)));
}

/// A line headed for a purchase order: part, quantity, price.
@immutable
class ProposedLine {
  const ProposedLine({
    required this.part,
    required this.qty,
    this.unitCents = 0,
    this.vendorPartNumber = '',
  });

  final CatalogPart part;
  final int qty;
  final int unitCents;
  final String vendorPartNumber;

  ProposedLine copyWith({int? qty, int? unitCents}) => ProposedLine(
        part: part,
        qty: qty ?? this.qty,
        unitCents: unitCents ?? this.unitCents,
        vendorPartNumber: vendorPartNumber,
      );
}

/// Key for the group of lines with no known vendor.
const String noVendorGroup = '';

/// Groups lines to order by the part's best current vendor. Parts with no
/// price go under [noVendorGroup]. Only lines with something to order are
/// included.
Map<String, List<ProposedLine>> groupByBestVendor(
  Iterable<ReorderLine> lines,
  Map<String, List<PartPrice>> pricesByPartId,
) {
  final out = <String, List<ProposedLine>>{};
  for (final l in lines) {
    final qty = l.orderQty;
    if (qty <= 0) continue;
    final best = summarizePrices(pricesByPartId[l.part.id] ?? const []).best;
    final key = best?.vendorId ?? noVendorGroup;
    out.putIfAbsent(key, () => []).add(ProposedLine(
          part: l.part,
          qty: qty,
          unitCents: best?.unitCents ?? 0,
          vendorPartNumber: best?.vendorPartNumber ?? '',
        ));
  }
  return out;
}
