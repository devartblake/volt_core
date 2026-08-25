import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/app/nav_extensions.dart';

/// A router whose routes are all reached by `go`, so nothing is ever
/// poppable — the situation the drawer creates when it navigates away from a
/// form.
GoRouter _router({required void Function(BuildContext) onFormAction}) {
  return GoRouter(
    initialLocation: '/form',
    routes: [
      GoRoute(
        path: '/form',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onFormAction(context),
              child: const Text('leave'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/list',
        builder: (context, _) => const Scaffold(body: Text('list page')),
      ),
      GoRoute(
        path: '/pushed',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.popIfPossible(),
              child: const Text('leave'),
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  group('popIfPossible', () {
    testWidgets('does not throw when there is nothing to pop', (tester) async {
      // The reported crash: GoError "There is nothing to pop", thrown from the
      // inspection form's unsaved-changes guard after the drawer had already
      // navigated away with `go`.
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: _router(onFormAction: (c) => c.popIfPossible()),
      ));

      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('reports that it did not pop', (tester) async {
      bool? popped;
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: _router(onFormAction: (c) => popped = c.popIfPossible()),
      ));

      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(popped, isFalse);
    });

    testWidgets('pops for real when a route was pushed', (tester) async {
      late GoRouter router;
      router = _router(onFormAction: (c) => c.go('/pushed'));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.push('/pushed');
      await tester.pumpAndSettle();
      expect(find.text('leave'), findsOneWidget);

      // The pushed route sits on top of /form, so this is a genuine back.
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), '/form');
    });
  });

  group('popOrGo', () {
    testWidgets('lands on the fallback when nothing can be popped',
        (tester) async {
      // Used after a save, where leaving the technician on the form is not an
      // acceptable outcome.
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: _router(onFormAction: (c) => c.popOrGo('/list')),
      ));

      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('list page'), findsOneWidget);
    });
  });
}
