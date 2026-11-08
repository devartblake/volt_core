import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/division.dart';
import 'package:voltcore/modules/admin/infra/division_repository.dart';
import 'package:voltcore/modules/admin/presenter/pages/divisions_page.dart';

class FakeDivisionRepository implements DivisionRepository {
  FakeDivisionRepository(List<Division> start, {this.offline = false})
      : items = List.of(start);

  final List<Division> items;
  final bool offline;
  final calls = <String>[];

  @override
  Future<List<Division>> list() async {
    if (offline) throw const DivisionsOfflineException();
    return sortedDivisions(items);
  }

  @override
  Future<Division> add(String name) async {
    calls.add('add:$name');
    if (items.any((d) => d.name.toLowerCase() == name.toLowerCase())) {
      throw const DivisionNameTakenException();
    }
    final d = Division(id: 'd${items.length + 1}', name: name, sortOrder: items.length);
    items.add(d);
    return d;
  }

  @override
  Future<void> rename(String id, String name) async {
    calls.add('rename:$id:$name');
    final i = items.indexWhere((d) => d.id == id);
    items[i] = items[i].copyWith(name: name);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    calls.add('active:$id:$isActive');
    final i = items.indexWhere((d) => d.id == id);
    items[i] = items[i].copyWith(isActive: isActive);
  }

  @override
  Future<void> reorder(List<Division> ordered) async {
    calls.add('reorder:${ordered.map((d) => d.id).join(',')}');
    for (var i = 0; i < ordered.length; i++) {
      final at = items.indexWhere((d) => d.id == ordered[i].id);
      items[at] = items[at].copyWith(sortOrder: i);
    }
  }
}

const _generators = Division(id: 'd1', name: 'Generators', sortOrder: 0);
const _fire = Division(id: 'd2', name: 'Fire alarm', sortOrder: 1);
const _old = Division(id: 'd3', name: 'Legacy', sortOrder: 2, isActive: false);

Future<void> _pump(
  WidgetTester t,
  FakeDivisionRepository repo, {
  Size size = const Size(360, 800),
  double scale = 1.3,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [divisionRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const DivisionsPage(),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Division model', () {
    test('fromJson reads a row and defaults', () {
      final d = Division.fromJson(
          {'id': 'x', 'name': ' Fire alarm ', 'sort_order': 3, 'is_active': false});
      expect(d, const Division(id: 'x', name: 'Fire alarm', sortOrder: 3, isActive: false));
      final bare = Division.fromJson({'id': 'y', 'name': 'A'})!;
      expect(bare.sortOrder, 0);
      expect(bare.isActive, isTrue);
    });

    test('fromJson refuses rows without an id or a name', () {
      expect(Division.fromJson({'name': 'A'}), isNull);
      expect(Division.fromJson({'id': 'x', 'name': '  '}), isNull);
    });

    test('sortedDivisions orders by sort order, then name', () {
      final sorted = sortedDivisions([
        const Division(id: '1', name: 'b', sortOrder: 1),
        const Division(id: '2', name: 'z', sortOrder: 0),
        const Division(id: '3', name: 'A', sortOrder: 1),
      ]);
      expect(sorted.map((d) => d.id), ['2', '3', '1']);
    });

    test('divisionNameOf finds a name or returns null', () {
      expect(divisionNameOf('d1', [_generators, _fire]), 'Generators');
      expect(divisionNameOf('nope', [_generators]), isNull);
      expect(divisionNameOf(null, [_generators]), isNull);
      expect(divisionNameOf('', [_generators]), isNull);
    });

    test('names are required, short, and unique ignoring case', () {
      expect(validateDivisionName('  ', const []), 'Enter a name.');
      expect(validateDivisionName(null, const []), 'Enter a name.');
      expect(validateDivisionName('x' * 61, const []), contains('60'));
      expect(validateDivisionName('GENERATORS ', [_generators]),
          'A division with that name already exists.');
      expect(validateDivisionName('Solar', [_generators]), isNull);
    });
  });

  group('repository seam', () {
    test('the provider hands back what the repository lists, in order', () async {
      final repo = FakeDivisionRepository([_fire, _generators]);
      final container = ProviderContainer(
          overrides: [divisionRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      final list = await container.read(divisionsProvider.future);
      expect(list.map((d) => d.name), ['Generators', 'Fire alarm']);
    });

    test('offline surfaces the "Connect" message', () async {
      final repo = FakeDivisionRepository(const [], offline: true);
      final container = ProviderContainer(
          overrides: [divisionRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      await expectLater(
          container.read(divisionsProvider.future),
          throwsA(isA<DivisionsOfflineException>()));
      expect(const DivisionsOfflineException().toString(),
          'Connect to the internet to manage divisions.');
    });
  });

  group('Divisions page', () {
    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      testWidgets('lists divisions with no overflow at 1.3x on ${size.width.toInt()}px',
          (t) async {
        final repo = FakeDivisionRepository([_generators, _fire, _old]);
        await _pump(t, repo, size: size);
        expect(t.takeException(), isNull);
        expect(find.text('Generators'), findsOneWidget);
        expect(find.text('Fire alarm'), findsOneWidget);
        expect(find.text('Legacy'), findsOneWidget);
        expect(find.text('Not offered'), findsOneWidget);
        expect(find.text('Add division'), findsOneWidget);
      });
    }

    testWidgets('offline shows Connect message and Retry', (t) async {
      await _pump(t, FakeDivisionRepository(const [], offline: true));
      expect(find.text('Connect to the internet to manage divisions.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('empty state invites the first division', (t) async {
      await _pump(t, FakeDivisionRepository(const []));
      expect(find.text('No divisions yet'), findsOneWidget);
    });

    testWidgets('add: validates, then saves', (t) async {
      final repo = FakeDivisionRepository([_generators]);
      await _pump(t, repo);
      await t.tap(find.text('Add division'));
      await t.pumpAndSettle();

      await t.tap(find.text('Save'));
      await t.pump();
      expect(find.text('Enter a name.'), findsOneWidget);

      await t.enterText(find.byType(TextFormField), 'generators');
      await t.tap(find.text('Save'));
      await t.pump();
      expect(find.text('A division with that name already exists.'),
          findsOneWidget);
      expect(repo.calls, isEmpty);

      await t.enterText(find.byType(TextFormField), '  Solar ');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.calls, ['add:Solar']);
      expect(find.text('Solar'), findsOneWidget);
    });

    testWidgets('rename saves the new name', (t) async {
      final repo = FakeDivisionRepository([_generators, _fire]);
      await _pump(t, repo);
      await t.tap(find.byTooltip('Rename Fire alarm'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), 'Fire & life safety');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.calls, ['rename:d2:Fire & life safety']);
      expect(find.text('Fire & life safety'), findsOneWidget);
    });

    testWidgets('the switch deactivates and reactivates', (t) async {
      final repo = FakeDivisionRepository([_generators]);
      await _pump(t, repo);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(repo.calls, ['active:d1:false']);
      expect(find.text('Not offered'), findsOneWidget);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(repo.calls.last, 'active:d1:true');
    });

    testWidgets('a failed write says so in plain words', (t) async {
      final repo = FakeDivisionRepository([_generators], offline: false);
      await _pump(t, repo);
      repo.items.clear(); // rename will now throw RangeError inside the fake
      await t.tap(find.byTooltip('Rename Generators'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), 'Other');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Could not save the change. Try again.'),
          findsOneWidget);
    });
  });
}
