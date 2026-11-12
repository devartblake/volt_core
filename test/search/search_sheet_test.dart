import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/modules/search/domain/search_index.dart';
import 'package:voltcore/modules/search/presenter/global_search.dart';
import 'package:voltcore/modules/search/presenter/recent_searches_provider.dart';

class FakeRecentStorage implements RecentSearchStorage {
  FakeRecentStorage([List<String> initial = const []]) : value = [...initial];
  List<String> value;

  @override
  List<String> read() => value;

  @override
  Future<void> write(List<String> v) async => value = v;
}

const _entries = [
  SearchEntry(kind: SearchKind.page, title: 'Stock', route: '/inventory', isPage: true),
  SearchEntry(kind: SearchKind.part, title: 'LF3000', subtitle: 'Oil filter', route: '/inventory'),
  SearchEntry(kind: SearchKind.vehicle, title: 'Truck LF', route: '/fleet/1'),
];

Widget _app([FakeRecentStorage? storage]) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (c, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showGlobalSearch(c),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    GoRoute(path: '/inventory', builder: (_, __) => const Scaffold(body: Text('INVENTORY'))),
    GoRoute(path: '/fleet/1', builder: (_, __) => const Scaffold(body: Text('TRUCK'))),
  ]);
  return ProviderScope(
    overrides: [
      searchIndexProvider.overrideWith((ref) async => _entries),
      recentSearchStorageProvider
          .overrideWithValue(storage ?? FakeRecentStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('opens as a sheet over the page and filters by kind', (t) async {
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // A sheet: the page is still in the tree behind it.
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(GlobalSearchSheet), findsOneWidget);

    await t.enterText(find.byKey(const Key('search_field')), 'lf');
    await t.pump();
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('LF3000'), findsOneWidget);
    expect(find.text('Truck LF'), findsOneWidget);

    await t.tap(find.byKey(const Key('filter_part')));
    await t.pump();
    expect(find.text('LF3000'), findsOneWidget);
    expect(find.text('Truck LF'), findsNothing);
  });

  testWidgets('choosing a result closes the sheet and navigates', (t) async {
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('search_field')), 'truck');
    await t.pump();
    await t.tap(find.text('Truck LF'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.byType(GlobalSearchSheet), findsNothing);
    expect(find.text('TRUCK'), findsOneWidget);
  });

  testWidgets('opening a result stores the query as a recent search', (t) async {
    final storage = FakeRecentStorage(['older']);
    await t.pumpWidget(_app(storage));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('search_field')), 'truck');
    await t.pump();
    await t.tap(find.text('Truck LF'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(storage.value, ['truck', 'older']);
  });

  testWidgets('recent searches show before typing, refill the field, clear',
      (t) async {
    final storage = FakeRecentStorage(['truck', 'lf3000']);
    await t.pumpWidget(_app(storage));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'truck'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'lf3000'), findsOneWidget);

    await t.tap(find.widgetWithText(ActionChip, 'lf3000'));
    await t.pump();
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('LF3000'), findsWidgets);

    // Back to empty, then clear.
    await t.tap(find.byTooltip('Clear'));
    await t.pump();
    await t.tap(find.byKey(const Key('clear_recent_searches')));
    await t.pump();
    expect(find.text('RECENT SEARCHES'), findsNothing);
    expect(storage.value, isEmpty);
  });
}
