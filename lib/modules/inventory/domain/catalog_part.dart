import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../materials/domain/material_item.dart';

/// A part number reduced to letters and digits, upper case, so "af-123",
/// "AF 123" and "AF123" are the same part. Used to find duplicates and
/// matches; the original text is what is shown.
String partKey(String partNumber) =>
    partNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// One part in the catalog: what it is, not how many there are.
@immutable
class CatalogPart {
  const CatalogPart({
    required this.id,
    required this.partNumber,
    this.name = '',
    this.manufacturer = '',
    this.slot,
    this.unit = 'each',
    this.minStock = 0,
    this.altPartNumbers = const [],
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partNumber;
  final String name;
  final String manufacturer;

  /// The material slot it fits (oil filter, battery...), or null when general.
  final MaterialSlot? slot;
  final String unit;

  /// Stock at or below this is "low". Zero means no minimum is set.
  final int minStock;

  /// Other part numbers that can be used in its place.
  final List<String> altPartNumbers;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "Fleetguard LF3000" style title: name when there is one, else the number.
  String get title => name.trim().isNotEmpty ? name.trim() : partNumber.trim();

  /// Whether [number] is this part's number or one of its alternates.
  bool matchesNumber(String number) {
    final k = partKey(number);
    if (k.isEmpty) return false;
    return partKey(partNumber) == k || altPartNumbers.any((a) => partKey(a) == k);
  }

  CatalogPart copyWith({
    String? partNumber,
    String? name,
    String? manufacturer,
    Object? slot = _keep,
    String? unit,
    int? minStock,
    List<String>? altPartNumbers,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return CatalogPart(
      id: id,
      partNumber: partNumber ?? this.partNumber,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      slot: identical(slot, _keep) ? this.slot : slot as MaterialSlot?,
      unit: unit ?? this.unit,
      minStock: minStock == null ? this.minStock : (minStock < 0 ? 0 : minStock),
      altPartNumbers: altPartNumbers ?? this.altPartNumbers,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'partNumber': partNumber,
        'name': name,
        'manufacturer': manufacturer,
        'slot': slot?.wire,
        'unit': unit,
        'minStock': minStock,
        'altPartNumbers': altPartNumbers,
        'notes': notes,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static CatalogPart? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final number = json['partNumber']?.toString() ?? '';
    if (id.isEmpty || number.trim().isEmpty) return null;
    final now = DateTime.now().toUtc();
    final min = json['minStock'];
    final alts = json['altPartNumbers'];
    return CatalogPart(
      id: id,
      partNumber: number,
      name: json['name']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      slot: MaterialSlot.fromWire(json['slot']?.toString()),
      unit: json['unit']?.toString() ?? 'each',
      minStock: min is int ? min : int.tryParse('$min') ?? 0,
      altPartNumbers: alts is List ? [for (final a in alts) a.toString()] : const [],
      notes: json['notes']?.toString() ?? '',
      isActive: json['isActive'] != false,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? now,
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? now,
    );
  }

  static String encode(CatalogPart p) => jsonEncode(p.toJson());

  static CatalogPart? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? fromJson(Map<String, dynamic>.from(v)) : null;
    } catch (_) {
      return null;
    }
  }
}

/// The catalog part for [number] (its own number or an alternate), or null.
CatalogPart? findPartByNumber(Iterable<CatalogPart> parts, String number) {
  if (partKey(number).isEmpty) return null;
  for (final p in parts) {
    if (p.isActive && p.matchesNumber(number)) return p;
  }
  return null;
}

/// Ranks [parts] against [query]. Every word must appear in the part number,
/// an alternate, the name or the manufacturer; part numbers that start with
/// the query rank first. Empty query returns nothing.
List<CatalogPart> searchParts(
  Iterable<CatalogPart> parts,
  String query, {
  int limit = 30,
  bool includeInactive = false,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final qKey = partKey(query);

  final scored = <({CatalogPart part, int score, int order})>[];
  var order = 0;
  for (final p in parts) {
    order++;
    if (!p.isActive && !includeInactive) continue;
    final hay = [
      p.partNumber,
      ...p.altPartNumbers,
      p.name,
      p.manufacturer,
    ].join(' ').toLowerCase();
    final hayKey = partKey(hay);
    final ok = words.every((w) => hay.contains(w) || (partKey(w).isNotEmpty && hayKey.contains(partKey(w))));
    if (!ok) continue;

    var score = 0;
    final own = partKey(p.partNumber);
    if (qKey.isNotEmpty && own == qKey) {
      score += 100;
    } else if (qKey.isNotEmpty && own.startsWith(qKey)) {
      score += 50;
    } else if (qKey.isNotEmpty && own.contains(qKey)) {
      score += 25;
    }
    if (p.title.toLowerCase().startsWith(words.first)) score += 10;
    scored.add((part: p, score: score, order: order));
  }
  scored.sort((a, b) {
    final s = b.score.compareTo(a.score);
    return s != 0 ? s : a.order.compareTo(b.order);
  });
  return [for (final s in scored.take(limit)) s.part];
}
