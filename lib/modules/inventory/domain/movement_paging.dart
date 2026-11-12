/// Client-side paging for the movements ledger: filters run over the full
/// set, then only the first [visible] of the filtered result are shown.
const int kMovementsPageSize = 50;

class PagedSlice<T> {
  const PagedSlice(this.items, this.total);

  /// The first `visible` entries.
  final List<T> items;

  /// Size of the whole (filtered) list.
  final int total;

  int get remaining => total - items.length;
  bool get hasMore => remaining > 0;
}

/// The first [visible] entries of [all] (all of them when fewer).
PagedSlice<T> pageSlice<T>(List<T> all, int visible) {
  final n = visible < 0
      ? 0
      : (visible > all.length ? all.length : visible);
  return PagedSlice<T>(n == all.length ? all : all.sublist(0, n), all.length);
}
