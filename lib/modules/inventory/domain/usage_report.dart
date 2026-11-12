import 'package:flutter/foundation.dart';

import 'catalog_part.dart';
import 'stock.dart';

/// The span a usage report covers.
enum UsagePeriod {
  days30('Last 30 days'),
  days90('Last 90 days'),
  year('Last 12 months'),
  all('All time');

  const UsagePeriod(this.label);

  final String label;

  DateTime? start(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (this) {
      days30 => day.subtract(const Duration(days: 29)),
      days90 => day.subtract(const Duration(days: 89)),
      year => DateTime(day.year - 1, day.month, day.day),
      all => null,
    };
  }
}

/// The generator a job was for.
@immutable
class UsageGenerator {
  const UsageGenerator({required this.key, required this.label});

  /// The generator's profile key.
  final String key;
  final String label;
}

@immutable
class UsageRow {
  const UsageRow({
    required this.key,
    required this.label,
    this.detail = '',
    required this.qty,
    this.costCents,
    this.jobs = 0,
  });

  final String key;
  final String label;
  final String detail;

  /// Issued, net of returns.
  final int qty;

  /// Null when costs are not shown or nothing in the row has a price.
  final int? costCents;

  /// Distinct jobs (generator rows only).
  final int jobs;
}

@immutable
class UsageReport {
  const UsageReport({
    required this.totalQty,
    required this.totalCostCents,
    required this.unpricedParts,
    required this.byPart,
    required this.byManufacturer,
    required this.byMonth,
    required this.byGenerator,
    required this.noGeneratorQty,
  });

  final int totalQty;

  /// Null when costs are not included.
  final int? totalCostCents;

  /// Parts that were issued but have no price paid on record.
  final int unpricedParts;
  final List<UsageRow> byPart;
  final List<UsageRow> byManufacturer;

  /// Oldest month first; keys are `yyyy-MM`.
  final List<UsageRow> byMonth;
  final List<UsageRow> byGenerator;

  /// Issued quantity whose job does not resolve to a generator.
  final int noGeneratorQty;

  bool get isEmpty => byPart.isEmpty;
}

class _Acc {
  int qty = 0;
  int cost = 0;
  bool priced = false;
  final Set<String> jobs = {};
}

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Quantities issued (net of returns) in [from]..[to], by part, manufacturer,
/// month and generator.
///
/// [generatorOf] maps a `job_ref` to the generator it was for. [lastPaidCents]
/// maps part id to the last price paid; pass null to leave costs out (prices
/// are admin-only).
UsageReport computeUsageReport(
  Iterable<InventoryMovement> movements,
  Iterable<CatalogPart> parts, {
  DateTime? from,
  DateTime? to,
  Map<String, UsageGenerator> generatorOf = const {},
  Map<String, int>? lastPaidCents,
}) {
  final byId = {for (final p in parts) p.id: p};
  final costs = lastPaidCents != null;

  final part = <String, _Acc>{};
  final maker = <String, _Acc>{};
  final month = <String, _Acc>{};
  final gen = <String, _Acc>{};
  final genLabel = <String, String>{};
  var total = 0;
  var totalCost = 0;
  var noGen = 0;
  final unpriced = <String>{};

  for (final m in movements) {
    if (m.reason != MovementReason.issue &&
        m.reason != MovementReason.returned) {
      continue;
    }
    final at = m.at.toLocal();
    if (from != null && at.isBefore(from)) continue;
    if (to != null && !at.isBefore(to)) continue;

    // Issue is negative, return positive: the net issued is the negation.
    final q = -m.qtyDelta;
    final price = lastPaidCents?[m.partId];
    final cost = price == null ? 0 : price * q;
    final p = byId[m.partId];

    void add(Map<String, _Acc> into, String key, {String? job}) {
      final a = into.putIfAbsent(key, _Acc.new);
      a.qty += q;
      if (price != null) {
        a.cost += cost;
        a.priced = true;
      }
      if (job != null) a.jobs.add(job);
    }

    add(part, m.partId);
    add(
      maker,
      (p == null || p.manufacturer.trim().isEmpty)
          ? 'Unknown'
          : p.manufacturer.trim(),
    );
    add(month, _monthKey(at));
    total += q;
    if (price != null) {
      totalCost += cost;
    } else if (costs) {
      unpriced.add(m.partId);
    }

    final g = m.jobRef == null ? null : generatorOf[m.jobRef];
    if (g == null) {
      noGen += q;
    } else {
      genLabel[g.key] = g.label;
      add(gen, g.key, job: m.jobRef);
    }
  }

  List<UsageRow> rows(
    Map<String, _Acc> src, {
    String Function(String)? label,
    String Function(String)? detail,
    bool byQty = true,
  }) {
    final out = [
      for (final e in src.entries)
        if (e.value.qty != 0)
          UsageRow(
            key: e.key,
            label: label?.call(e.key) ?? e.key,
            detail: detail?.call(e.key) ?? '',
            qty: e.value.qty,
            costCents: costs && e.value.priced ? e.value.cost : null,
            jobs: e.value.jobs.length,
          ),
    ];
    if (byQty) {
      out.sort((a, b) {
        final c = b.qty.compareTo(a.qty);
        return c != 0 ? c : a.label.compareTo(b.label);
      });
    } else {
      out.sort((a, b) => a.key.compareTo(b.key));
    }
    return out;
  }

  return UsageReport(
    totalQty: total,
    totalCostCents: costs ? totalCost : null,
    unpricedParts: unpriced.length,
    byPart: rows(
      part,
      label: (id) => byId[id]?.partNumber ?? 'Removed part',
      detail: (id) => [
        byId[id]?.name ?? '',
        byId[id]?.manufacturer ?? '',
      ].where((s) => s.trim().isNotEmpty).join(' · '),
    ),
    byManufacturer: rows(maker),
    byMonth: rows(month, byQty: false),
    byGenerator: rows(gen, label: (k) => genLabel[k] ?? k),
    noGeneratorQty: noGen,
  );
}

String _csv(String v) => v.contains(RegExp(r'[",\n\r]'))
    ? '"${v.replaceAll('"', '""')}"'
    : v;

String _money(int? cents) {
  if (cents == null) return '';
  final abs = cents.abs();
  return '${cents < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

/// The report as CSV: one row per line of each breakdown, with a Cost column
/// only when costs were computed.
String usageReportCsv(UsageReport r) {
  final withCost = r.totalCostCents != null;
  final b = StringBuffer();
  void row(List<String> cells) => b.write('${cells.map(_csv).join(',')}\r\n');

  row(['Breakdown', 'Name', 'Detail', 'Qty issued', if (withCost) 'Cost']);
  void section(String name, List<UsageRow> rows, {bool showJobs = false}) {
    for (final x in rows) {
      row([
        name,
        x.label,
        showJobs ? '${x.jobs} jobs' : x.detail,
        '${x.qty}',
        if (withCost) _money(x.costCents),
      ]);
    }
  }

  section('Part', r.byPart);
  section('Manufacturer', r.byManufacturer);
  section('Month', r.byMonth);
  section('Generator', r.byGenerator, showJobs: true);
  if (r.noGeneratorQty != 0) {
    row([
      'Generator',
      'No generator',
      '',
      '${r.noGeneratorQty}',
      if (withCost) '',
    ]);
  }
  row(['Total', '', '', '${r.totalQty}', if (withCost) _money(r.totalCostCents)]);
  return b.toString();
}
