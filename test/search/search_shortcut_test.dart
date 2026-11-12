import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/app/app_shells.dart';
import 'package:voltcore/modules/search/domain/search_index.dart';
import 'package:voltcore/modules/search/presenter/global_search.dart';
import 'package:voltcore/modules/search/presenter/recent_searches_provider.dart';

class _Mem implements RecentSearchStorage {
  @override
  List<String> read() => const [];
  @override
  Future<void> write(List<String> v) async {}
}

Widget _app() {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(
        body: SearchShortcut(child: Center(child: TextField(key: Key('page_field')))),
      ),
    ),
  ]);
  return ProviderScope(
    overrides: [
      searchIndexProvider.overrideWith((ref) async => const <SearchEntry>[]),
      recentSearchStorageProvider.overrideWithValue(_Mem()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _chord(WidgetTester t, LogicalKeyboardKey modifier) async {
  await t.sendKeyDownEvent(modifier);
  await t.sendKeyEvent(LogicalKeyboardKey.keyK);
  await t.sendKeyUpEvent(modifier);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Ctrl+K opens the search sheet', (t) async {
    await t.pumpWidget(_app());
    await t.pump();
    expect(find.byType(GlobalSearchSheet), findsNothing);
    await _chord(t, LogicalKeyboardKey.controlLeft);
    expect(find.byType(GlobalSearchSheet), findsOneWidget);
  });

  testWidgets('Cmd+K opens the search sheet', (t) async {
    await t.pumpWidget(_app());
    await t.pump();
    await _chord(t, LogicalKeyboardKey.metaLeft);
    expect(find.byType(GlobalSearchSheet), findsOneWidget);
  });

  testWidgets('works while a text field on the page has focus', (t) async {
    await t.pumpWidget(_app());
    await t.tap(find.byKey(const Key('page_field')));
    await t.pump();
    await _chord(t, LogicalKeyboardKey.controlLeft);
    expect(find.byType(GlobalSearchSheet), findsOneWidget);
  });

  testWidgets('plain K does nothing', (t) async {
    await t.pumpWidget(_app());
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(GlobalSearchSheet), findsNothing);
  });
}
