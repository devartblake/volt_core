/// Most recent equipment queries kept.
const int maxRecentEquipmentSearches = 8;

/// Returns [current] with [query] added at the front: trimmed, whitespace
/// collapsed, de-duplicated case-insensitively (the newest spelling wins) and
/// capped at [max]. A blank query leaves the list unchanged.
List<String> addRecentEquipmentSearch(
  List<String> current,
  String query, {
  int max = maxRecentEquipmentSearches,
}) {
  final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (q.isEmpty) return List.of(current);
  final key = q.toLowerCase();
  return [
    q,
    for (final c in current)
      if (c.trim().toLowerCase() != key) c,
  ].take(max).toList();
}
