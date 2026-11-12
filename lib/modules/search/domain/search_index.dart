import 'package:flutter/material.dart';

/// What a search result is. Also the order results are grouped in.
enum SearchKind {
  page('Pages', Icons.apps_outlined),
  inspection('Inspections', Icons.fact_check_outlined),
  maintenance('Maintenance', Icons.build_circle_outlined),
  job('Jobs', Icons.work_outline),
  vehicle('Vehicles', Icons.local_shipping_outlined),
  customer('Customers & sites', Icons.business_outlined),
  equipment('Equipment', Icons.precision_manufacturing_outlined),
  task('Schedule', Icons.event_outlined),
  part('Parts', Icons.inventory_2_outlined);

  const SearchKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One thing the search can find.
@immutable
class SearchEntry {
  const SearchEntry({
    required this.kind,
    required this.title,
    required this.route,
    this.subtitle = '',
    this.keywords = '',
    this.icon,
    this.isPage = false,
  });

  final SearchKind kind;
  final String title;
  final String subtitle;

  /// Extra words that should match but are not shown (serial numbers, codes).
  final String keywords;

  /// Where tapping it goes.
  final String route;
  final IconData? icon;

  /// A top-level menu page: opened with `go` (replacing the stack) rather than
  /// `push`, like choosing it from the menu.
  final bool isPage;

  String get _haystack =>
      '${title.toLowerCase()} ${subtitle.toLowerCase()} ${keywords.toLowerCase()}';
}

/// Ranks [entries] against [query]: every word must appear somewhere, titles
/// matching at the start of a word rank first, pages rank above records for
/// the same match, and ties keep their original order.
///
/// An empty query returns nothing - callers show their own suggestions.
List<SearchEntry> searchEntries(
  List<SearchEntry> entries,
  String query, {
  int limit = 40,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];

  final scored = <({SearchEntry entry, int score, int order})>[];
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final hay = e._haystack;
    if (!words.every(hay.contains)) continue;

    final title = e.title.toLowerCase();
    var score = 0;
    for (final w in words) {
      if (title.startsWith(w)) {
        score += 30;
      } else if (title.contains(' $w')) {
        score += 20;
      } else if (title.contains(w)) {
        score += 10;
      } else {
        score += 1;
      }
    }
    if (e.isPage) score += 5;
    scored.add((entry: e, score: score, order: i));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return [for (final s in scored.take(limit)) s.entry];
}

/// Groups results by [SearchKind], in enum order, dropping empty groups.
Map<SearchKind, List<SearchEntry>> groupByKind(List<SearchEntry> results) {
  final out = <SearchKind, List<SearchEntry>>{};
  for (final kind in SearchKind.values) {
    final inKind = results.where((r) => r.kind == kind).toList();
    if (inKind.isNotEmpty) out[kind] = inKind;
  }
  return out;
}
