import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/search/domain/recent_searches.dart';

void main() {
  test('adds newest first', () {
    expect(addRecentSearch(['a'], 'b'), ['b', 'a']);
  });

  test('moves a repeat to the front, case-insensitively, keeping new casing',
      () {
    expect(addRecentSearch(['b', 'Truck', 'a'], 'truck'), ['truck', 'b', 'a']);
  });

  test('trims and collapses whitespace; blank is ignored', () {
    expect(addRecentSearch(['a'], '  gen   22 '), ['gen 22', 'a']);
    expect(addRecentSearch(['a'], '   '), ['a']);
  });

  test('caps at eight, dropping the oldest', () {
    var list = <String>[];
    for (var i = 1; i <= 10; i++) {
      list = addRecentSearch(list, 'q$i');
    }
    expect(list.length, 8);
    expect(list.first, 'q10');
    expect(list.last, 'q3');
  });

  test('does not mutate the input', () {
    final input = ['a'];
    addRecentSearch(input, 'b');
    expect(input, ['a']);
  });
}
