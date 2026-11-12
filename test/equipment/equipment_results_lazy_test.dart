import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/equipment/presenter/widgets/equipment_result_card.dart';
import 'package:voltcore/modules/equipment/presenter/widgets/equipment_results.dart';
import 'package:voltcore/providers/equipment_providers.dart';

void main() {
  testWidgets('equipment results build cards lazily (300 assets)', (t) async {
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    final assets = [
      for (var i = 0; i < 300; i++)
        Equipment(
          id: 'a$i',
          name: 'Asset $i',
          make: 'Make',
          model: 'M',
          serialNumber: 'SN-$i',
          voltage: '480V',
          location: 'Loc',
          hasInspectionLink: false,
        ),
    ];
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: Scaffold(
          body: EquipmentResults(
            equipment: assets,
            registryIsEmpty: false,
            hasFilters: false,
            twoPane: false,
            onClearFilters: () {},
            onEditAssignment: (_) {},
            onOpened: () {},
          ),
        ),
      ),
    ));
    await t.pump();
    final built = find.byType(EquipmentResultCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
    expect(find.text('300 results found'), findsOneWidget);
  });
}
