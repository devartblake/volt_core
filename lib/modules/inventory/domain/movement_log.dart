import 'package:flutter/foundation.dart';

import '../../materials/domain/material_item.dart';
import 'catalog_part.dart';
import 'stock.dart';

/// How far back the Movements list looks.
enum MovementPeriod {
  today('Today'),
  week('7 days'),
  month('30 days'),
  all('All');

  const MovementPeriod(this.label);

  final String label;

  /// The start of the window, or null for "all".
  DateTime? start(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (this) {
      today => day,
      week => day.subtract(const Duration(days: 6)),
      month => day.subtract(const Duration(days: 29)),
      all => null,
    };
  }
}

/// What a movement's `job_ref` points at.
@immutable
class JobRef {
  const JobRef(this.type, this.id);

  final MaterialOwnerType type;
  final String id;
}

/// Reads `inspection:ID` / `maintenance:ID`; null for anything else.
JobRef? parseJobRef(String? ref) {
  if (ref == null) return null;
  final i = ref.indexOf(':');
  if (i <= 0 || i == ref.length - 1) return null;
  final id = ref.substring(i + 1).trim();
  if (id.isEmpty) return null;
  final type = switch (ref.substring(0, i)) {
    'inspection' => MaterialOwnerType.inspection,
    'maintenance' => MaterialOwnerType.maintenance,
    _ => null,
  };
  return type == null ? null : JobRef(type, id);
}

/// Who made a movement: their name when known, else a short id, else "-".
String movementUserLabel(String? userId, Map<String, String> names) {
  if (userId == null || userId.trim().isEmpty) return '-';
  final name = names[userId]?.trim();
  if (name != null && name.isNotEmpty) return name;
  return userId.length <= 6 ? userId : userId.substring(0, 6);
}

bool _matches(CatalogPart? part, String q) {
  final needle = q.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final hay = [
    part?.partNumber ?? '',
    part?.name ?? '',
    part?.manufacturer ?? '',
    ...?part?.altPartNumbers,
  ].join(' ').toLowerCase();
  if (hay.contains(needle)) return true;
  final key = partKey(needle);
  return key.isNotEmpty && partKey(hay).contains(key);
}

/// The ledger narrowed to [reasons] (empty = every reason), [period] and a
/// part search, newest first. [parts] maps part id to the catalog part.
List<InventoryMovement> filterMovements(
  Iterable<InventoryMovement> movements, {
  required Map<String, CatalogPart> parts,
  Set<MovementReason> reasons = const {},
  MovementPeriod period = MovementPeriod.all,
  String query = '',
  required DateTime now,
}) {
  final from = period.start(now);
  final out = [
    for (final m in movements)
      if ((reasons.isEmpty || reasons.contains(m.reason)) &&
          (from == null || !m.at.toLocal().isBefore(from)) &&
          _matches(parts[m.partId], query))
        m,
  ]..sort((a, b) => b.at.compareTo(a.at));
  return out;
}

@immutable
class MovementDay {
  const MovementDay(this.day, this.movements);

  /// Local midnight.
  final DateTime day;
  final List<InventoryMovement> movements;
}

/// [movements] (already newest first) split by local calendar day, newest day
/// first.
List<MovementDay> groupMovementsByDay(Iterable<InventoryMovement> movements) {
  final days = <MovementDay>[];
  DateTime? current;
  var bucket = <InventoryMovement>[];
  for (final m in movements) {
    final l = m.at.toLocal();
    final d = DateTime(l.year, l.month, l.day);
    if (current != d) {
      if (current != null) days.add(MovementDay(current, bucket));
      current = d;
      bucket = [];
    }
    bucket.add(m);
  }
  if (current != null) days.add(MovementDay(current, bucket));
  return days;
}
