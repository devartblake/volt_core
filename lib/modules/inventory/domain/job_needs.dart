import 'package:flutter/foundation.dart';

import '../../materials/domain/material_item.dart';
import '../../materials/domain/material_list.dart';
import 'catalog_part.dart';
import 'stock.dart';

/// How well the warehouse covers one needed part.
enum NeedStatus {
  /// Taken out of the warehouse for the job.
  issued('Issued'),

  /// Set aside for the job.
  reserved('Reserved'),

  /// Enough on the shelf, not yet set aside.
  available('In stock'),

  /// Some on the shelf, not all.
  partial('Partly in stock'),

  /// None available.
  short('Short'),

  /// The part number is not in the catalog, so stock is unknown.
  notInCatalog('Not in catalog');

  const NeedStatus(this.label);

  final String label;
}

/// `inspection:ID` or `maintenance:ID` - what a movement's `job_ref` holds.
String jobRefFor(MaterialOwnerType type, String id) => '${type.wire}:$id';

/// One job with the parts it needs.
@immutable
class JobNeedsInput {
  const JobNeedsInput({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.date,
    required this.items,
    this.allItemsNeeded = false,
  });

  final MaterialOwnerType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime? date;

  /// The job's whole materials list; the ones flagged for replacement are the
  /// needs.
  final List<MaterialItem> items;

  /// A scheduled maintenance that is not finished: every listed item with a
  /// part number is a need (maintenance lists have no "needs replacement"
  /// switch). Otherwise only items flagged for replacement count.
  final bool allItemsNeeded;

  /// The items of [items] that are needs.
  List<MaterialItem> get neededItems => allItemsNeeded
      ? [
          for (final i in items)
            if (i.hasPartNumber) i,
        ]
      : MaterialListOps.needed(items);

  String get jobRef => jobRefFor(type, id);
}

@immutable
class NeedLine {
  const NeedLine({
    required this.item,
    required this.jobRef,
    required this.part,
    required this.usingAlternate,
    required this.required,
    required this.reserved,
    required this.issued,
    required this.available,
    required this.status,
  });

  final MaterialItem item;
  final String jobRef;

  /// The catalog part this resolves to (by its number or an alternate).
  final CatalogPart? part;
  final bool usingAlternate;
  final int required;

  /// Set aside for this job.
  final int reserved;

  /// Out of the warehouse for this job (issued less returned).
  final int issued;

  /// On the shelf and not promised to any job.
  final int available;
  final NeedStatus status;

  /// Still to be covered.
  int get outstanding {
    final n = required - reserved - issued;
    return n < 0 ? 0 : n;
  }

  /// How many more are needed than the shelf can give.
  int get shortBy {
    final n = outstanding - available;
    return n < 0 ? 0 : n;
  }
}

@immutable
class JobNeeds {
  const JobNeeds({required this.job, required this.lines});

  final JobNeedsInput job;
  final List<NeedLine> lines;

  bool get isCovered => lines.every((l) =>
      l.status == NeedStatus.reserved || l.status == NeedStatus.issued);

  int get shortCount => lines
      .where((l) =>
          l.status == NeedStatus.short ||
          l.status == NeedStatus.partial ||
          l.status == NeedStatus.notInCatalog)
      .length;
}

/// The needs lines for [jobs], checked against the catalog, the ledger and the
/// stock. Jobs with nothing flagged are left out.
List<JobNeeds> computeJobNeeds(
  Iterable<JobNeedsInput> jobs,
  Iterable<CatalogPart> parts,
  Iterable<InventoryMovement> movements,
) {
  final partList = parts.toList();
  final levels = {for (final l in computeStock(partList, movements)) l.part.id: l};

  // Per job and part: what is set aside and what is out with the job.
  final reserved = <String, int>{};
  final out = <String, int>{};
  for (final m in movements) {
    final ref = m.jobRef;
    if (ref == null || ref.isEmpty) continue;
    final key = '$ref|${m.partId}';
    switch (m.reason) {
      case MovementReason.reserve:
        reserved[key] = (reserved[key] ?? 0) + m.qtyDelta;
      case MovementReason.release:
        reserved[key] = (reserved[key] ?? 0) - m.qtyDelta;
      case MovementReason.issue || MovementReason.returned:
        // Issue is negative, return positive: net out is the negation.
        out[key] = (out[key] ?? 0) - m.qtyDelta;
      case MovementReason.receive ||
            MovementReason.adjust ||
            MovementReason.count ||
            MovementReason.transfer:
        break;
    }
  }

  final result = <JobNeeds>[];
  for (final job in jobs) {
    final lines = <NeedLine>[];
    for (final item in job.neededItems) {
      final qty = item.quantity < 1 ? 1 : item.quantity;
      final part = findPartByNumber(partList, item.partNumber);
      if (part == null) {
        lines.add(NeedLine(
          item: item,
          jobRef: job.jobRef,
          part: null,
          usingAlternate: false,
          required: qty,
          reserved: 0,
          issued: 0,
          available: 0,
          status: NeedStatus.notInCatalog,
        ));
        continue;
      }
      final key = '${job.jobRef}|${part.id}';
      final res = (reserved[key] ?? 0).clamp(0, 1 << 30);
      final iss = (out[key] ?? 0).clamp(0, 1 << 30);
      final level = levels[part.id]!;
      final avail = level.available < 0 ? 0 : level.available;
      final remaining = qty - res - iss;

      final NeedStatus status;
      if (iss >= qty) {
        status = NeedStatus.issued;
      } else if (res + iss >= qty) {
        status = NeedStatus.reserved;
      } else if (avail >= remaining) {
        status = NeedStatus.available;
      } else if (avail > 0) {
        status = NeedStatus.partial;
      } else {
        status = NeedStatus.short;
      }

      lines.add(NeedLine(
        item: item,
        jobRef: job.jobRef,
        part: part,
        usingAlternate: partKey(item.partNumber) != partKey(part.partNumber),
        required: qty,
        reserved: res,
        issued: iss,
        available: avail,
        status: status,
      ));
    }
    if (lines.isNotEmpty) result.add(JobNeeds(job: job, lines: lines));
  }

  // Soonest first; jobs without a date last, then by title.
  result.sort((a, b) {
    final da = a.job.date, db = b.job.date;
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return a.job.title.compareTo(b.job.title);
  });
  return result;
}

/// A part that is needed by jobs and cannot be fully covered from the shelf.
@immutable
class Shortage {
  const Shortage({
    required this.partNumber,
    required this.name,
    required this.part,
    required this.needed,
    required this.available,
    required this.jobs,
  });

  final String partNumber;
  final String name;

  /// Null when the part number is not in the catalog.
  final CatalogPart? part;

  /// Still uncovered across all jobs.
  final int needed;

  /// On the shelf and not promised.
  final int available;

  /// How many jobs want it.
  final int jobs;

  int get shortBy {
    final n = needed - available;
    return n < 0 ? 0 : n;
  }
}

/// Everything to order: per part, the quantity jobs still need beyond what is
/// available, largest gap first. Parts outside the catalog are listed too
/// (their stock is unknown, so the whole quantity is shown as short).
List<Shortage> computeShortages(List<JobNeeds> needs) {
  final byKey = <String, ({CatalogPart? part, String number, String name, int needed, int available, Set<String> jobs})>{};

  for (final job in needs) {
    for (final l in job.lines) {
      if (l.status == NeedStatus.issued || l.status == NeedStatus.reserved) {
        continue;
      }
      final key = l.part?.id ?? 'x:${partKey(l.item.partNumber)}';
      final prev = byKey[key];
      byKey[key] = (
        part: l.part,
        number: l.part?.partNumber ?? l.item.partNumber,
        name: l.part?.title ?? l.item.partName,
        needed: (prev?.needed ?? 0) + l.outstanding,
        available: l.available,
        jobs: {...?prev?.jobs, job.job.jobRef},
      );
    }
  }

  final out = [
    for (final e in byKey.values)
      Shortage(
        partNumber: e.number,
        name: e.name,
        part: e.part,
        needed: e.needed,
        available: e.available,
        jobs: e.jobs.length,
      ),
  ].where((s) => s.shortBy > 0).toList()
    ..sort((a, b) {
      final c = b.shortBy.compareTo(a.shortBy);
      return c != 0 ? c : a.partNumber.compareTo(b.partNumber);
    });
  return out;
}

/// Parts at or below their minimum (with a minimum set).
List<StockLevel> lowStockParts(Iterable<StockLevel> levels) {
  final low = [
    for (final l in levels)
      if (l.part.isActive &&
          l.part.minStock > 0 &&
          l.available <= l.part.minStock)
        l,
  ]..sort((a, b) => a.available.compareTo(b.available));
  return low;
}
