import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'catalog_part.dart';

/// Why stock changed. The ledger is append-only: a wrong entry is corrected
/// with an offsetting adjustment, never edited.
enum MovementReason {
  /// Stock arrived. Positive.
  receive('receive', 'Received', true),

  /// A correction, up or down.
  adjust('adjust', 'Adjustment', true),

  /// A physical count: the difference found, up or down.
  count('count', 'Stock count', true),

  /// Set aside for a job (reserved goes up; on hand does not change).
  reserve('reserve', 'Reserved', false),

  /// A reservation let go (reserved goes down).
  release('release', 'Released', false),

  /// Taken for a job. Negative.
  issue('issue', 'Issued', true),

  /// Unused part brought back. Positive.
  returned('return', 'Returned', true),

  /// Moved between locations: a negative at the source and a positive at the
  /// destination. Nets to zero company-wide.
  transfer('transfer', 'Transfer', true);

  const MovementReason(this.wire, this.label, this.changesOnHand);

  final String wire;
  final String label;

  /// Whether it moves the on-hand count (reserve / release move the
  /// reserved count instead).
  final bool changesOnHand;

  static MovementReason? fromWire(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// One line of the ledger.
@immutable
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.partId,
    required this.qtyDelta,
    required this.reason,
    required this.at,
    this.locationId = 'main',
    this.note = '',
    this.jobRef,
    this.userId,
  });

  final String id;
  final String partId;

  /// Signed.
  final int qtyDelta;
  final MovementReason reason;
  final DateTime at;

  /// "main" until there is a company to name the warehouse after.
  final String locationId;
  final String note;
  final String? jobRef;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'partId': partId,
        'qtyDelta': qtyDelta,
        'reason': reason.wire,
        'at': at.toIso8601String(),
        'locationId': locationId,
        'note': note,
        'jobRef': jobRef,
        'userId': userId,
      };

  static InventoryMovement? fromJson(Map<String, dynamic> json) {
    final reason = MovementReason.fromWire(json['reason']?.toString());
    final id = json['id']?.toString() ?? '';
    final part = json['partId']?.toString() ?? '';
    if (reason == null || id.isEmpty || part.isEmpty) return null;
    final delta = json['qtyDelta'];
    return InventoryMovement(
      id: id,
      partId: part,
      qtyDelta: delta is int ? delta : int.tryParse('$delta') ?? 0,
      reason: reason,
      at: DateTime.tryParse('${json['at']}') ?? DateTime.now().toUtc(),
      locationId: json['locationId']?.toString() ?? 'main',
      note: json['note']?.toString() ?? '',
      jobRef: json['jobRef']?.toString(),
      userId: json['userId']?.toString(),
    );
  }

  static String encode(InventoryMovement m) => jsonEncode(m.toJson());

  static InventoryMovement? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? fromJson(Map<String, dynamic>.from(v)) : null;
    } catch (_) {
      return null;
    }
  }
}

enum StockStatus {
  /// Nothing on hand.
  out('Out of stock'),

  /// At or below the part's minimum.
  low('Low'),

  ok('In stock');

  const StockStatus(this.label);

  final String label;
}

/// How much of one part there is.
@immutable
class StockLevel {
  const StockLevel({
    required this.part,
    required this.onHand,
    required this.reserved,
  });

  final CatalogPart part;
  final int onHand;
  final int reserved;

  /// What can still be promised to a job.
  int get available => onHand - reserved;

  /// Offline entries can briefly take stock below zero; a supervisor then
  /// reconciles it rather than either person being blocked.
  bool get needsReconciliation => onHand < 0;

  StockStatus get status {
    if (onHand <= 0) return StockStatus.out;
    if (part.minStock > 0 && available <= part.minStock) return StockStatus.low;
    return StockStatus.ok;
  }
}

/// Stock for every part, worked out from the ledger: on hand is the sum of
/// the movements that change it, reserved the reservations less releases.
/// Parts with no movements are in the list with zero.
List<StockLevel> computeStock(
  Iterable<CatalogPart> parts,
  Iterable<InventoryMovement> movements,
) {
  final onHand = <String, int>{};
  final reserved = <String, int>{};
  for (final m in movements) {
    switch (m.reason) {
      case MovementReason.reserve:
        reserved[m.partId] = (reserved[m.partId] ?? 0) + m.qtyDelta;
      case MovementReason.release:
        reserved[m.partId] = (reserved[m.partId] ?? 0) - m.qtyDelta;
      case MovementReason.receive ||
            MovementReason.adjust ||
            MovementReason.count ||
            MovementReason.issue ||
            MovementReason.returned ||
            MovementReason.transfer:
        onHand[m.partId] = (onHand[m.partId] ?? 0) + m.qtyDelta;
    }
  }
  return [
    for (final p in parts)
      StockLevel(
        part: p,
        onHand: onHand[p.id] ?? 0,
        reserved: reserved[p.id] ?? 0,
      ),
  ];
}

/// Stock held at one location (a warehouse or a truck) only. Transfers count
/// here: they are what moves parts onto and off a truck.
List<StockLevel> computeStockAt(
  Iterable<CatalogPart> parts,
  Iterable<InventoryMovement> movements,
  String locationId,
) =>
    computeStock(
      parts,
      movements.where((m) => m.locationId == locationId),
    );

enum StockFilter {
  all('All'),
  low('Low'),
  out('Out of stock');

  const StockFilter(this.label);

  final String label;
}

/// Active parts matching the filter and search, sorted by part number.
/// "Low" includes out-of-stock parts that have a minimum set, because those
/// are low too.
List<StockLevel> filterStock(
  Iterable<StockLevel> levels, {
  StockFilter filter = StockFilter.all,
  String query = '',
}) {
  Iterable<StockLevel> out = levels.where((l) => l.part.isActive);

  out = switch (filter) {
    StockFilter.all => out,
    StockFilter.out => out.where((l) => l.status == StockStatus.out),
    StockFilter.low => out.where((l) =>
        l.status == StockStatus.low ||
        (l.status == StockStatus.out && l.part.minStock > 0)),
  };

  final q = query.trim();
  if (q.isNotEmpty) {
    final hits = searchParts([for (final l in out) l.part], q, limit: 10000)
        .map((p) => p.id)
        .toSet();
    out = out.where((l) => hits.contains(l.part.id));
  }

  final list = out.toList()
    ..sort((a, b) => partKey(a.part.partNumber)
        .compareTo(partKey(b.part.partNumber)));
  return list;
}

/// Counts for the summary tiles.
({int parts, int low, int out}) stockSummary(Iterable<StockLevel> levels) {
  var parts = 0, low = 0, out = 0;
  for (final l in levels) {
    if (!l.part.isActive) continue;
    parts++;
    if (l.status == StockStatus.out) {
      out++;
    } else if (l.status == StockStatus.low) {
      low++;
    }
  }
  return (parts: parts, low: low, out: out);
}
