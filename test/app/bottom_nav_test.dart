import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/app_bottom_nav.dart';
import 'package:voltcore/app/nav_config.dart';
import 'package:voltcore/app/nav_style_provider.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

Widget _host(
  List<NavSection> sections,
  String location, {
  int max = 5,
  bool showMore = true,
  double textScale = 1.0,
}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        drawer: const Drawer(child: Text('the full menu')),
        body: const SizedBox(),
        bottomNavigationBar: AppBottomNav(
          sections: sections,
          location: location,
          maxDestinations: max,
          showMore: showMore,
        ),
      ),
    );

void main() {
  final admin = navSectionsForRole(UserRole.admin);

  group('AppBottomNav.isTopLevel', () {
    test('menu pages are top level, detail pages are not', () {
      expect(AppBottomNav.isTopLevel(admin, RoutePaths.inspections), isTrue);
      expect(AppBottomNav.isTopLevel(admin, '${RoutePaths.inspections}/'),
          isTrue);
      expect(AppBottomNav.isTopLevel(admin, RoutePaths.schedule), isTrue);
      expect(
          AppBottomNav.isTopLevel(admin, '${RoutePaths.inspections}/abc-123'),
          isFalse);
      expect(AppBottomNav.isTopLevel(admin, '/nowhere'), isFalse);
    });
  });

  group('phone bar', () {
    testWidgets('shows four sections and More when there are more than five',
        (tester) async {
      await tester.pumpWidget(_host(admin, RoutePaths.dashboard));
      await tester.pump();

      expect(admin.length, greaterThan(5));
      for (final s in admin.take(4)) {
        expect(find.text(s.destinationLabel), findsOneWidget);
      }
      expect(find.text('More'), findsOneWidget);
      // Sections beyond the fourth live behind More.
      expect(find.text(admin[5].destinationLabel), findsNothing);
    });

    testWidgets('More opens the full menu', (tester) async {
      await tester.pumpWidget(_host(admin, RoutePaths.dashboard));
      await tester.pump();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('the full menu'), findsOneWidget);
    });

    testWidgets('a page behind More highlights More', (tester) async {
      await tester.pumpWidget(_host(admin, RoutePaths.customerSites));
      await tester.pump();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 4);
    });

    testWidgets('the current section is highlighted', (tester) async {
      await tester.pumpWidget(_host(admin, RoutePaths.workOrders));
      await tester.pump();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(admin[bar.selectedIndex].title, 'Work');
    });

    testWidgets('a role with five or fewer sections gets no More',
        (tester) async {
      final few = admin.take(5).toList();
      await tester.pumpWidget(_host(few, RoutePaths.dashboard));
      await tester.pump();
      expect(find.text('More'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('fits at 1.3x text on a 360 dp phone', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _host(admin, RoutePaths.dashboard, textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('tablet bar', () {
    testWidgets('lists every section and no More', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _host(admin, RoutePaths.dashboard, max: 8, showMore: false));
      await tester.pump();

      expect(find.byType(NavigationDestination), findsNWidgets(admin.length));
      expect(find.text('More'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('NavStyle', () {
    test('decodes stored values, defaulting to the rail', () {
      expect(NavStyle.decode('bottom'), NavStyle.bottom);
      expect(NavStyle.decode('rail'), NavStyle.rail);
      expect(NavStyle.decode('anything else'), NavStyle.rail);
      expect(NavStyle.decode(''), NavStyle.rail);
    });
  });
}
