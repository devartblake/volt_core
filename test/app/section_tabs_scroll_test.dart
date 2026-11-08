import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/app_drawer.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

void main() {
  test('the readiness tab is named Generator Fleet Readiness', () {
    final item = navSectionsForRole(UserRole.admin)
        .expand((s) => s.items)
        .firstWhere((i) => i.route == RoutePaths.readiness);
    expect(item.label, 'Generator Fleet Readiness');
    expect(item.description, contains('ready'));
  });

  testWidgets('the Home section tabs scroll sideways at 360 dp, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final overflows = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        overflows.add(d.exceptionAsString());
      } else {
        old?.call(d);
      }
    };
    addTearDown(() => FlutterError.onError = old);

    final home = navSectionsForRole(UserRole.admin)
        .firstWhere((s) => s.items.any((i) => i.route == RoutePaths.readiness));
    final tabs = [
      for (final i in home.items)
        SectionTab(
          label: i.label,
          icon: i.icon,
          route: i.route,
          selected: i.route == RoutePaths.readiness,
        ),
    ];
    expect(tabs.length, greaterThanOrEqualTo(3));

    await tester.pumpWidget(MaterialApp(
      home: AppShellScope(
        isCompact: true,
        drawer: null,
        sectionTabs: tabs,
        child: const AppPage(title: 'Generator Fleet Readiness', body: SizedBox()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final row = find.descendant(
        of: find.bySemanticsLabel('Section pages'), matching: find.byType(Scrollable));
    final scroll = tester.state<ScrollableState>(row.first);
    expect(scroll.position.axis, Axis.horizontal);
    expect(scroll.position.maxScrollExtent, greaterThan(0),
        reason: 'the chips are wider than the screen, so the row must scroll');

    final last = find.widgetWithText(ChoiceChip, tabs.last.label);
    await tester.drag(row.first, const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scroll.position.pixels, scroll.position.maxScrollExtent);
    expect(last, findsOneWidget);
    expect(overflows, isEmpty);
  });
}
