import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_list_page.dart';

VehicleEntity _vehicle(String id, String name, VehicleStatus status) =>
    VehicleEntity(
      id: id,
      tenantId: 't',
      designation: name,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('each card shows a status badge and a daily-check badge',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final doneToday = VehicleInspection.newDraft(
            vehicleId: 'a', cadence: InspectionCadence.daily)
        .copyWith(inspectedAt: DateTime.now());
    final old = VehicleInspection.newDraft(
            vehicleId: 'b', cadence: InspectionCadence.daily)
        .copyWith(inspectedAt: DateTime.now().subtract(const Duration(days: 5)));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        fleetManagerProvider.overrideWithValue(true),
        fleetVisibleVehiclesProvider.overrideWith((ref) async => [
              _vehicle('a', 'Truck A', VehicleStatus.active),
              _vehicle('b', 'Truck B', VehicleStatus.maintenance),
              _vehicle('c', 'Truck C', VehicleStatus.outOfService),
            ]),
        vehicleInspectionsProvider('a').overrideWith((ref) async => [doneToday]),
        vehicleInspectionsProvider('b').overrideWith((ref) async => [old]),
        vehicleInspectionsProvider('c').overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: const VehicleListPage(),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('In maintenance'), findsOneWidget);
    expect(find.text('Out of service'), findsOneWidget);
    expect(find.text('Daily check: done today'), findsOneWidget);
    expect(find.text('Daily check: overdue'), findsOneWidget);
    expect(find.text('Daily check: due'), findsOneWidget);
  });
}
