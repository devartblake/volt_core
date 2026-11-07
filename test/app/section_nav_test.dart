import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/app_drawer.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

List<String> _titles(UserRole role) =>
    navSectionsForRole(role).map((s) => s.title ?? '').toList();

void main() {
  group('consolidated navigation', () {
    test('related pages share one section', () {
      final work = navSectionsForRole(UserRole.admin)
          .firstWhere((s) => s.title == 'Work');
      expect(work.items.map((i) => i.label),
          ['Jobs', 'Maintenance', 'Schedule', 'Archive', 'Documents']);

      final settings = navSectionsForRole(UserRole.admin)
          .firstWhere((s) => s.title == 'Settings');
      expect(settings.items.map((i) => i.label),
          ['Settings', 'Configuration', 'About']);
    });

    test('create entries are not menu items (they are buttons on the lists)',
        () {
      final labels = navSectionsForRole(UserRole.admin)
          .expand((s) => s.items)
          .map((i) => i.label)
          .toList();
      expect(labels, isNot(contains('Create Inspection')));
      expect(labels, isNot(contains('Create Job')));
    });

    test('the rail has at most eight destinations, each labelled', () {
      for (final role in UserRole.values) {
        final sections = navSectionsForRole(role);
        expect(sections.length, lessThanOrEqualTo(8), reason: '$role');
        for (final s in sections) {
          expect(s.destinationLabel, isNotEmpty);
        }
      }
    });

    test('a technician never sees the Administration section', () {
      expect(_titles(UserRole.tech), isNot(contains('Administration')));
      expect(_titles(UserRole.admin), contains('Administration'));
    });

    test('every page that used to be reachable still is', () {
      final routes = navSectionsForRole(UserRole.admin)
          .expand((s) => s.items)
          .map((i) => i.route)
          .toSet();
      expect(
        routes,
        containsAll([
          RoutePaths.dashboard,
          RoutePaths.analytics,
          RoutePaths.inspections,
          RoutePaths.inspectionsPending,
          RoutePaths.workOrders,
          RoutePaths.maintenance,
          RoutePaths.schedule,
          RoutePaths.maintenanceArchive,
          RoutePaths.fleet,
          RoutePaths.fleetInspectionLog,
          RoutePaths.fleetCatalog,
          RoutePaths.customerSites,
          RoutePaths.nameplateList,
          RoutePaths.materialsApprovals,
          RoutePaths.documents,
          RoutePaths.inventory,
          RoutePaths.inventoryCatalog,
          RoutePaths.inventoryNeeds,
          RoutePaths.inventoryShortages,
          RoutePaths.inventoryVendors,
          RoutePaths.inventoryMovements,
          RoutePaths.inventoryOrders,
          RoutePaths.settings,
          RoutePaths.selectionManagement,
          RoutePaths.about,
          RoutePaths.adminDashboard,
          RoutePaths.adminTechnicians,
          RoutePaths.tenants,
          RoutePaths.adminSettings,
        ]),
      );
    });
  });

  group('sectionNavFor', () {
    test('lists the sibling pages and marks the current one', () {
      final nav = sectionNavFor(UserRole.admin, RoutePaths.schedule)!;
      expect(nav.items.map((i) => i.label),
          ['Jobs', 'Maintenance', 'Schedule', 'Archive', 'Documents']);
      expect(nav.selected?.label, 'Schedule');
    });

    test('a nested route selects its most specific page', () {
      final nav =
          sectionNavFor(UserRole.admin, RoutePaths.maintenanceArchive)!;
      expect(nav.selected?.label, 'Archive');
    });

    test('Documents is a tab in the Work section', () {
      final nav = sectionNavFor(UserRole.admin, RoutePaths.documents)!;
      expect(nav.selected?.label, 'Documents');
      expect(nav.items.first.label, 'Jobs');
    });

    test('Inventory has Stock and Catalog tabs for everyone; Vendors is admin only', () {
      const shared = ['Stock', 'Job Needs', 'Shortages', 'Parts Catalog'];
      final tech = sectionNavFor(UserRole.tech, RoutePaths.inventory)!;
      expect(tech.items.map((i) => i.label), shared);
      final admin = sectionNavFor(UserRole.admin, RoutePaths.inventory)!;
      expect(admin.items.map((i) => i.label),
          containsAllInOrder([...shared, 'Orders', 'Vendors']));
      expect(tech.items.map((i) => i.label), isNot(contains('Orders')));
    });

    test('unknown routes and signed-out users have none', () {
      expect(sectionNavFor(UserRole.admin, '/nowhere'), isNull);
      expect(sectionNavFor(null, RoutePaths.schedule), isNull);
    });

    test('tabs only include pages the role may open', () {
      final nav = sectionNavFor(UserRole.tech, RoutePaths.fleet);
      final admin = sectionNavFor(UserRole.admin, RoutePaths.fleet)!;
      expect((nav?.items.length ?? 0), lessThanOrEqualTo(admin.items.length));
    });
  });

  group('AppPage section tabs', () {
    testWidgets('shows the tabs and highlights the current page',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppShellScope(
          isCompact: false,
          drawer: null,
          sectionTabs: const [
            SectionTab(
                label: 'Jobs',
                icon: Icons.work_outline,
                route: '/jobs',
                selected: false),
            SectionTab(
                label: 'Schedule',
                icon: Icons.calendar_month_outlined,
                route: '/schedule',
                selected: true),
          ],
          child: const AppPage(title: 'Schedule', body: SizedBox()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.widgetWithText(ChoiceChip, 'Jobs'), findsOneWidget);
      final current =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Schedule'));
      expect(current.selected, isTrue);
    });

    testWidgets('a page that brings its own bottom keeps it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppShellScope(
          isCompact: false,
          drawer: null,
          sectionTabs: const [
            SectionTab(
                label: 'A', icon: Icons.add, route: '/a', selected: true),
            SectionTab(
                label: 'B', icon: Icons.add, route: '/b', selected: false),
          ],
          child: AppPage(
            title: 'T',
            body: const SizedBox(),
            appBarBottom: const PreferredSize(
              preferredSize: Size.fromHeight(40),
              child: Text('own bottom'),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('own bottom'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('no tabs when the page has no siblings', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AppPage(title: 'Solo', body: SizedBox()),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });
}
