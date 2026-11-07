import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/equipment/domain/recent_equipment_searches.dart';
import 'package:voltcore/modules/equipment/presenter/recent_equipment_searches_provider.dart';

class FakeRecentEquipmentStorage implements RecentEquipmentSearchStorage {
  FakeRecentEquipmentStorage([List<String> initial = const []])
      : value = [...initial];
  List<String> value;

  @override
  List<String> read() => value;

  @override
  Future<void> write(List<String> v) async => value = v;
}

void main() {
  group('addRecentEquipmentSearch', () {
    test('puts the newest query first', () {
      expect(addRecentEquipmentSearch(['a'], 'b'), ['b', 'a']);
    });

    test('trims and collapses whitespace', () {
      expect(addRecentEquipmentSearch([], '  CAT   C32  '), ['CAT C32']);
    });

    test('ignores blank queries', () {
      expect(addRecentEquipmentSearch(['a'], '   '), ['a']);
      expect(addRecentEquipmentSearch(['a'], ''), ['a']);
    });

    test('de-duplicates case-insensitively, newest spelling wins', () {
      expect(
        addRecentEquipmentSearch(['x', 'cat c32', 'y'], 'CAT  C32'),
        ['CAT C32', 'x', 'y'],
      );
    });

    test('keeps at most 8', () {
      var list = <String>[];
      for (var i = 0; i < 12; i++) {
        list = addRecentEquipmentSearch(list, 'q$i');
      }
      expect(list.length, 8);
      expect(list.first, 'q11');
      expect(list.last, 'q4');
    });

    test('does not mutate the input', () {
      final input = ['a'];
      addRecentEquipmentSearch(input, 'b');
      expect(input, ['a']);
    });
  });

  group('recentEquipmentSearchesProvider', () {
    test('loads from, and saves to, its own storage', () async {
      final storage = FakeRecentEquipmentStorage(['old']);
      final container = ProviderContainer(overrides: [
        recentEquipmentSearchStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);

      expect(container.read(recentEquipmentSearchesProvider), ['old']);
      container.read(recentEquipmentSearchesProvider.notifier).add('new');
      expect(container.read(recentEquipmentSearchesProvider), ['new', 'old']);
      expect(storage.value, ['new', 'old']);

      container.read(recentEquipmentSearchesProvider.notifier).clear();
      expect(container.read(recentEquipmentSearchesProvider), isEmpty);
      expect(storage.value, isEmpty);
    });
  });
}
