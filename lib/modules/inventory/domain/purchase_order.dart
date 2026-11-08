import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PoStatus {
  draft('draft', 'Draft'),
  sent('sent', 'Sent'),
  partial('partial', 'Partly received'),
  received('received', 'Received'),
  cancelled('cancelled', 'Cancelled');

  const PoStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PoStatus fromWire(String? w) =>
      PoStatus.values.firstWhere((s) => s.wire == w, orElse: () => draft);

  /// Orders whose unreceived quantity still counts as "on order".
  bool get isOpen => this == sent || this == partial;

  /// Lines can still be edited.
  bool get isEditable => this == draft || this == sent;

  bool get isFinal => this == received || this == cancelled;
}

/// Whether an order may move from [from] to [to] by hand. Receiving moves
/// sent -> partial -> received on its own (see [statusAfterReceipt]).
bool canTransition(PoStatus from, PoStatus to) {
  if (from == to) return false;
  return switch (from) {
    PoStatus.draft => to == PoStatus.sent || to == PoStatus.cancelled,
    PoStatus.sent => to == PoStatus.partial ||
        to == PoStatus.received ||
        to == PoStatus.cancelled,
    PoStatus.partial => to == PoStatus.received || to == PoStatus.cancelled,
    PoStatus.received || PoStatus.cancelled => false,
  };
}

@immutable
class PoLine {
  const PoLine({
    required this.id,
    required this.partId,
    required this.qtyOrdered,
    this.qtyReceived = 0,
    this.unitCents = 0,
    this.vendorPartNumber = '',
  });

  final String id;
  final String partId;
  final int qtyOrdered;
  final int qtyReceived;

  /// Price of one, in cents.
  final int unitCents;
  final String vendorPartNumber;

  int get outstanding {
    final n = qtyOrdered - qtyReceived;
    return n < 0 ? 0 : n;
  }

  int get totalCents => qtyOrdered * unitCents;

  PoLine copyWith({
    int? qtyOrdered,
    int? qtyReceived,
    int? unitCents,
    String? vendorPartNumber,
  }) =>
      PoLine(
        id: id,
        partId: partId,
        qtyOrdered: qtyOrdered ?? this.qtyOrdered,
        qtyReceived: qtyReceived ?? this.qtyReceived,
        unitCents: unitCents ?? this.unitCents,
        vendorPartNumber: vendorPartNumber ?? this.vendorPartNumber,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'partId': partId,
        'qtyOrdered': qtyOrdered,
        'qtyReceived': qtyReceived,
        'unitCents': unitCents,
        'vendorPartNumber': vendorPartNumber,
      };

  static PoLine? fromJson(Map<String, dynamic> j) {
    final id = j['id'], partId = j['partId'];
    final ordered = j['qtyOrdered'];
    if (id is! String || partId is! String || ordered is! num) return null;
    return PoLine(
      id: id,
      partId: partId,
      qtyOrdered: ordered.round(),
      qtyReceived:
          (j['qtyReceived'] is num) ? (j['qtyReceived'] as num).round() : 0,
      unitCents: (j['unitCents'] is num) ? (j['unitCents'] as num).round() : 0,
      vendorPartNumber: (j['vendorPartNumber'] ?? '') as String,
    );
  }
}

@immutable
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    required this.vendorId,
    this.status = PoStatus.draft,
    required this.createdAt,
    required this.updatedAt,
    this.expectedOn,
    this.note = '',
    this.lines = const [],
  });

  final String id;

  /// Human number such as PO-0001; editable. A provisional "NEW-xxxxxxxx"
  /// until the order first syncs.
  final String number;
  final String vendorId;
  final PoStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expectedOn;
  final String note;
  final List<PoLine> lines;

  /// True until the server has assigned the real number.
  bool get numberPending => isProvisionalPoNumber(number);

  /// The number to show: "Number pending" or the real one.
  String get displayNumber => poNumberLabel(number);

  int get totalCents => lines.fold(0, (s, l) => s + l.totalCents);
  int get unitsOrdered => lines.fold(0, (s, l) => s + l.qtyOrdered);
  int get unitsReceived => lines.fold(0, (s, l) => s + l.qtyReceived);

  PurchaseOrder copyWith({
    String? number,
    String? vendorId,
    PoStatus? status,
    DateTime? updatedAt,
    DateTime? expectedOn,
    bool clearExpected = false,
    String? note,
    List<PoLine>? lines,
  }) =>
      PurchaseOrder(
        id: id,
        number: number ?? this.number,
        vendorId: vendorId ?? this.vendorId,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        expectedOn: clearExpected ? null : (expectedOn ?? this.expectedOn),
        note: note ?? this.note,
        lines: lines ?? this.lines,
      );

  /// The header only; lines are stored separately.
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'vendorId': vendorId,
        'status': status.wire,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'expectedOn': expectedOn?.toUtc().toIso8601String(),
        'note': note,
      };

  static PurchaseOrder? fromJson(Map<String, dynamic> j,
      {List<PoLine> lines = const []}) {
    final id = j['id'], number = j['number'], vendorId = j['vendorId'];
    final created = DateTime.tryParse('${j['createdAt']}');
    final updated = DateTime.tryParse('${j['updatedAt']}');
    if (id is! String ||
        number is! String ||
        vendorId is! String ||
        created == null ||
        updated == null) {
      return null;
    }
    return PurchaseOrder(
      id: id,
      number: number,
      vendorId: vendorId,
      status: PoStatus.fromWire(j['status'] as String?),
      createdAt: created,
      updatedAt: updated,
      expectedOn: DateTime.tryParse('${j['expectedOn']}'),
      note: (j['note'] ?? '') as String,
      lines: lines,
    );
  }

  static String encode(PurchaseOrder o) => jsonEncode(o.toJson());

  static PurchaseOrder? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------- helpers

/// Prefix of a provisional PO number. The database trigger replaces a number
/// starting with this by the next real "PO-0001" number when the order first
/// syncs (see supabase/migrations/20261111100000_po_numbers.sql).
const String kProvisionalPoPrefix = 'NEW-';

/// The provisional number for a new order: "NEW-" plus 8 characters of its id.
/// Unique per order, so two devices never collide while offline.
String provisionalPoNumber(String orderId) {
  final compact = orderId.replaceAll('-', '').toUpperCase();
  final short = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return '$kProvisionalPoPrefix$short';
}

/// Whether [number] is still waiting for the server to assign a real one.
bool isProvisionalPoNumber(String number) =>
    number.trim().startsWith(kProvisionalPoPrefix);

/// What to show people for [number]: "Number pending" until the real one
/// arrives.
String poNumberLabel(String number) =>
    isProvisionalPoNumber(number) ? 'Number pending' : number;

/// Status after goods are received against [o]: all lines in is received, any
/// in is partial, otherwise unchanged. Draft and final orders do not move.
PoStatus statusAfterReceipt(PurchaseOrder o) {
  if (o.status == PoStatus.draft || o.status.isFinal) return o.status;
  if (o.lines.isNotEmpty &&
      o.lines.every((l) => l.qtyReceived >= l.qtyOrdered)) {
    return PoStatus.received;
  }
  if (o.lines.any((l) => l.qtyReceived > 0)) return PoStatus.partial;
  return o.status;
}

/// Quantity still to arrive per part id, from sent and partly received orders.
Map<String, int> onOrderByPart(Iterable<PurchaseOrder> orders) {
  final out = <String, int>{};
  for (final o in orders) {
    if (!o.status.isOpen) continue;
    for (final l in o.lines) {
      final n = l.outstanding;
      if (n > 0) out[l.partId] = (out[l.partId] ?? 0) + n;
    }
  }
  return out;
}

/// Plain text for sharing an order with a vendor.
String poShareText(
  PurchaseOrder o, {
  required String vendorName,
  required String Function(String partId) partLabel,
  required String Function(int cents) money,
  String Function(DateTime d)? date,
}) {
  final b = StringBuffer()
    ..writeln('Purchase order ${o.displayNumber}')
    ..writeln('Vendor: $vendorName');
  if (o.expectedOn != null && date != null) {
    b.writeln('Expected: ${date(o.expectedOn!)}');
  }
  b.writeln();
  for (final l in o.lines) {
    b.write('${l.qtyOrdered} x ${partLabel(l.partId)}');
    if (l.vendorPartNumber.isNotEmpty) {
      b.write(' (vendor #${l.vendorPartNumber})');
    }
    if (l.unitCents > 0) {
      b.write(' @ ${money(l.unitCents)} = ${money(l.totalCents)}');
    }
    b.writeln();
  }
  b
    ..writeln()
    ..writeln('Total: ${money(o.totalCents)}');
  if (o.note.trim().isNotEmpty) b.writeln('Note: ${o.note.trim()}');
  return b.toString().trimRight();
}
