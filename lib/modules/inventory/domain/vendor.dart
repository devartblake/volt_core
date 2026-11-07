import 'dart:convert';

import 'catalog_part.dart';
import 'stock.dart';

/// Lower-cased letters and digits only, so "Ace Wire & Cable" and
/// "ace wire cable" are the same vendor.
String vendorKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// A company parts are bought from.
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.accountNumber = '',
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String contact;
  final String phone;
  final String email;
  final String accountNumber;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vendor copyWith({
    String? name,
    String? contact,
    String? phone,
    String? email,
    String? accountNumber,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) =>
      Vendor(
        id: id,
        name: name ?? this.name,
        contact: contact ?? this.contact,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        accountNumber: accountNumber ?? this.accountNumber,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contact': contact,
        'phone': phone,
        'email': email,
        'accountNumber': accountNumber,
        'notes': notes,
        'isActive': isActive,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static Vendor? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    final created = DateTime.tryParse('${j['createdAt']}');
    final updated = DateTime.tryParse('${j['updatedAt']}');
    if (id is! String || name is! String || created == null || updated == null) {
      return null;
    }
    String s(String k) => (j[k] ?? '') as String;
    return Vendor(
      id: id,
      name: name,
      contact: s('contact'),
      phone: s('phone'),
      email: s('email'),
      accountNumber: s('accountNumber'),
      notes: s('notes'),
      isActive: j['isActive'] != false,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static String encode(Vendor v) => jsonEncode(v.toJson());

  static Vendor? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }
}

/// A price paid, or quoted, for a part by a vendor. Entries are history: a new
/// price is a new entry, and the latest one per vendor is the current price.
enum PriceKind {
  paid('paid', 'Paid'),
  quote('quote', 'Quote');

  const PriceKind(this.wire, this.label);
  final String wire;
  final String label;

  static PriceKind fromWire(String? w) =>
      PriceKind.values.firstWhere((k) => k.wire == w, orElse: () => paid);
}

class PartPrice {
  const PartPrice({
    required this.id,
    required this.partId,
    required this.vendorId,
    required this.unitCents,
    this.kind = PriceKind.paid,
    this.vendorPartNumber = '',
    required this.pricedAt,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String partId;
  final String vendorId;

  /// Price of one unit, in cents, so sums are exact.
  final int unitCents;
  final PriceKind kind;

  /// The vendor's own number for the part, when it differs.
  final String vendorPartNumber;

  /// The date of the purchase or quote.
  final DateTime pricedAt;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'partId': partId,
        'vendorId': vendorId,
        'unitCents': unitCents,
        'kind': kind.wire,
        'vendorPartNumber': vendorPartNumber,
        'pricedAt': pricedAt.toUtc().toIso8601String(),
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static PartPrice? fromJson(Map<String, dynamic> j) {
    final id = j['id'], partId = j['partId'], vendorId = j['vendorId'];
    final cents = j['unitCents'];
    final priced = DateTime.tryParse('${j['pricedAt']}');
    final created = DateTime.tryParse('${j['createdAt']}');
    if (id is! String ||
        partId is! String ||
        vendorId is! String ||
        cents is! num ||
        priced == null ||
        created == null) {
      return null;
    }
    return PartPrice(
      id: id,
      partId: partId,
      vendorId: vendorId,
      unitCents: cents.round(),
      kind: PriceKind.fromWire(j['kind'] as String?),
      vendorPartNumber: (j['vendorPartNumber'] ?? '') as String,
      pricedAt: priced,
      note: (j['note'] ?? '') as String,
      createdAt: created,
    );
  }

  static String encode(PartPrice p) => jsonEncode(p.toJson());

  static PartPrice? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------- money

/// "12.5", "$1,234.50" or "12" as cents; null when it is not a price.
int? parseCents(String raw) {
  final t = raw.replaceAll(RegExp(r'[\s$,]'), '');
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final dollars = int.parse(m.group(1)!);
  final c = m.group(2);
  final cents = c == null ? 0 : int.parse(c.padRight(2, '0'));
  return dollars * 100 + cents;
}

/// 123456 -> "$1,234.56".
String formatCents(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString();
  final grouped = dollars.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final c = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}\$$grouped.$c';
}

// ---------------------------------------------------------------- summary

/// What a part costs, from its price history.
class PriceSummary {
  const PriceSummary({
    required this.currentByVendor,
    this.lastPaid,
    this.best,
  });

  /// The newest entry from each vendor.
  final Map<String, PartPrice> currentByVendor;

  /// The most recent price actually paid, from any vendor.
  final PartPrice? lastPaid;

  /// The lowest of the current vendor prices.
  final PartPrice? best;

  bool get isEmpty => currentByVendor.isEmpty;
}

int _newest(PartPrice a, PartPrice b) {
  final c = a.pricedAt.compareTo(b.pricedAt);
  return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
}

PriceSummary summarizePrices(Iterable<PartPrice> prices) {
  final current = <String, PartPrice>{};
  PartPrice? lastPaid;
  for (final p in prices) {
    final seen = current[p.vendorId];
    if (seen == null || _newest(p, seen) > 0) current[p.vendorId] = p;
    if (p.kind == PriceKind.paid && (lastPaid == null || _newest(p, lastPaid) > 0)) {
      lastPaid = p;
    }
  }
  PartPrice? best;
  for (final p in current.values) {
    if (best == null || p.unitCents < best.unitCents) best = p;
  }
  return PriceSummary(currentByVendor: current, lastPaid: lastPaid, best: best);
}

/// Prices grouped by part id.
Map<String, List<PartPrice>> pricesByPart(Iterable<PartPrice> prices) {
  final out = <String, List<PartPrice>>{};
  for (final p in prices) {
    out.putIfAbsent(p.partId, () => []).add(p);
  }
  return out;
}

/// What the shelf is worth: on hand × the last price paid. Parts with no paid
/// price are left out and counted in [unpriced].
({int cents, int unpriced}) stockValue(
  Iterable<StockLevel> levels,
  Map<String, List<PartPrice>> prices,
) {
  var total = 0;
  var unpriced = 0;
  for (final l in levels) {
    if (!l.part.isActive || l.onHand <= 0) continue;
    final last = summarizePrices(prices[l.part.id] ?? const []).lastPaid;
    if (last == null) {
      unpriced++;
    } else {
      total += last.unitCents * l.onHand;
    }
  }
  return (cents: total, unpriced: unpriced);
}

// ---------------------------------------------------------------- grouping

enum StockGroup {
  none('None'),
  manufacturer('Manufacturer'),
  slot('Type');

  const StockGroup(this.label);
  final String label;
}

const noManufacturerLabel = 'No manufacturer';
const noTypeLabel = 'Other';

/// The heading a stock row falls under.
String groupLabel(CatalogPart p, StockGroup by) => switch (by) {
      StockGroup.none => '',
      StockGroup.manufacturer =>
        p.manufacturer.trim().isEmpty ? noManufacturerLabel : p.manufacturer.trim(),
      StockGroup.slot => p.slot?.label ?? noTypeLabel,
    };

/// Splits [levels] into headed groups: alphabetical, with the "none" group
/// last, and parts in part-number order inside each. Grouping by manufacturer
/// ignores capitalisation, so "baldwin" and "Baldwin" share a heading.
List<({String label, List<StockLevel> levels})> groupStock(
  List<StockLevel> levels,
  StockGroup by,
) {
  int byNumber(StockLevel a, StockLevel b) =>
      partKey(a.part.partNumber).compareTo(partKey(b.part.partNumber));
  if (by == StockGroup.none) {
    return [(label: '', levels: List.of(levels)..sort(byNumber))];
  }
  final groups = <String, List<StockLevel>>{};
  final shown = <String, String>{};
  for (final l in levels) {
    final label = groupLabel(l.part, by);
    final k = label.toLowerCase();
    shown.putIfAbsent(k, () => label);
    groups.putIfAbsent(k, () => []).add(l);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final aLast = shown[a] == noManufacturerLabel || shown[a] == noTypeLabel;
      final bLast = shown[b] == noManufacturerLabel || shown[b] == noTypeLabel;
      if (aLast != bLast) return aLast ? 1 : -1;
      return a.compareTo(b);
    });
  return [
    for (final k in keys)
      (label: shown[k]!, levels: groups[k]!..sort(byNumber)),
  ];
}

/// The distinct manufacturers among [levels], alphabetical, spelled as first
/// seen.
List<String> manufacturersOf(Iterable<StockLevel> levels) {
  final seen = <String, String>{};
  for (final l in levels) {
    final m = l.part.manufacturer.trim();
    if (m.isNotEmpty) seen.putIfAbsent(m.toLowerCase(), () => m);
  }
  return (seen.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => e.value)
      .toList();
}
