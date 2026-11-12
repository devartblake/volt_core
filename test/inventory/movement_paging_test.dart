import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/movement_paging.dart';

void main() {
  final all = List.generate(120, (i) => i);

  test('first page is capped and reports what is left', () {
    final p = pageSlice(all, kMovementsPageSize);
    expect(p.items.length, 50);
    expect(p.total, 120);
    expect(p.remaining, 70);
    expect(p.hasMore, isTrue);
    expect(p.items.first, 0);
  });

  test('showing more extends, and the last page has no footer', () {
    final p = pageSlice(all, 150);
    expect(p.items.length, 120);
    expect(p.hasMore, isFalse);
    expect(pageSlice(all, 100).remaining, 20);
  });

  test('short and empty lists', () {
    expect(pageSlice(<int>[], 50).hasMore, isFalse);
    expect(pageSlice([1, 2], 50).items, [1, 2]);
    expect(pageSlice([1, 2], -3).items, isEmpty);
  });
}
