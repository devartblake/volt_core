import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_list_page.dart';

void main() {
  testWidgets('vehicle list builds rows lazily (300 vehicles)', (t) async {
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    final vehicles = [
      for (var i = 0; i < 300; i++)
        VehicleEntity(
          id: 'v$i',
          tenantId: 't',
          designation: 'Unit $i',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
    ];
    await t.pumpWidget(ProviderScope(
      overrides: [
        fleetManagerProvider.overrideWithValue(true),
        fleetVisibleVehiclesProvider.overrideWith((ref) async => vehicles),
        for (final v in vehicles)
          vehicleInspectionsProvider(v.id).overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: const VehicleListPage(),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    final built = find.byType(ListTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
    await t.scrollUntilVisible(find.textContaining('Unit 299'), 500,
        maxScrolls: 600, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Unit 299'), findsOneWidget);
  });
}
