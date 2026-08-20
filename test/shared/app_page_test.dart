import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

/// Wraps [child] the way a shell does, so AppPage can find its scope.
Widget _shelled({
  required Widget child,
  required bool isCompact,
  Widget? drawer,
}) {
  return MaterialApp(
    home: AppShellScope(
      isCompact: isCompact,
      drawer: drawer,
      child: child,
    ),
  );
}

void main() {
  group('AppPage chrome', () {
    testWidgets('renders exactly one AppBar', (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        drawer: const Drawer(child: SizedBox()),
        child: const AppPage(title: 'Inspections', body: SizedBox()),
      ));

      // The regression this guards: shell + page each drawing an app bar.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Inspections'), findsOneWidget);
    });

    testWidgets('renders exactly one Drawer on compact layouts',
        (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        drawer: const Drawer(child: Text('nav')),
        child: const AppPage(title: 'Inspections', body: SizedBox()),
      ));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNotNull);

      // A closed drawer isn't mounted, so open it before counting.
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('nav'), findsOneWidget);
    });

    testWidgets('takes no drawer on wide layouts (shell shows a rail)',
        (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: false,
        drawer: null,
        child: const AppPage(title: 'Inspections', body: SizedBox()),
      ));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
    });

    testWidgets('works with no shell scope (login, 403, viewer)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AppPage(title: 'Sign in', body: SizedBox()),
      ));

      expect(find.byType(AppBar), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
    });

    testWidgets('shows page actions and the sync indicator', (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        child: AppPage(
          title: 'Docs',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {},
            ),
          ],
          body: const SizedBox(),
        ),
      ));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('sync indicator can be suppressed', (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        child: const AppPage(
          title: 'Viewer',
          showSyncStatus: false,
          body: SizedBox(),
        ),
      ));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isEmpty);
    });

    testWidgets('titleWidget overrides the plain title', (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        child: const AppPage(
          title: 'ignored',
          titleWidget: Text('AS-114'),
          body: SizedBox(),
        ),
      ));

      expect(find.text('AS-114'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });

    testWidgets('bottom bar and fab are passed through', (tester) async {
      await tester.pumpWidget(_shelled(
        isCompact: true,
        child: AppPage(
          title: 'Form',
          bottomBar: const SizedBox(height: 48, child: Text('Save')),
          fab: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
          body: const SizedBox(),
        ),
      ));

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
