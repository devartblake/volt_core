/// Most recent queries kept.
const int maxRecentSearches = 8;

/// Returns [current] with [query] added at the front: trimmed, de-duplicated
/// case-insensitively (the newest spelling wins) and capped at [max].
/// A blank query leaves the list unchanged.
List<String> addRecentSearch(
  List<String> current,
  String query, {
  int max = maxRecentSearches,
}) {
  final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (q.isEmpty) return List.of(current);
  final key = q.toLowerCase();
  final out = <String>[
    q,
    for (final c in current)
      if (c.trim().toLowerCase() != key) c,
  ];
  return out.take(max).toList();
}
