import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_inspection_log_page.dart';
import 'package:voltcore/modules/inspections/presenter/inspection_date_filter.dart';

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

VehicleEntity _vehicle(String id, String name) => VehicleEntity(
      id: id,
      tenantId: 't',
      designation: name,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

VehicleInspection _insp(
  String vehicleId,
  InspectionCadence cadence,
  DateTime at,
) =>
    VehicleInspection.newDraft(vehicleId: vehicleId, cadence: cadence)
        .copyWith(inspectedAt: at, driverName: 'Sam', dispatcherName: 'Dana');

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9, 30);
  final longAgo = DateTime(now.year - 1, 3, 10, 8, 0);

  final vehicles = [_vehicle('a', 'Truck A'), _vehicle('b', 'Truck B')];
  final inspections = [
    _insp('a', InspectionCadence.daily, today),
    _insp('a', InspectionCadence.weekly, longAgo),
    _insp('b', InspectionCadence.monthly, longAgo),
  ];

  Widget app({List<VehicleEntity>? list, List<VehicleInspection>? data}) =>
      ProviderScope(
        overrides: [
          fleetVisibleVehiclesProvider
              .overrideWith((ref) async => list ?? vehicles),
          allVehicleInspectionsProvider
              .overrideWith((ref) async => data ?? inspections),
        ],
        child: const MaterialApp(home: VehicleInspectionLogPage()),
      );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('each vehicle gets its own log with its own entries',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('Truck A'), findsOneWidget);
    expect(find.text('Truck B'), findsOneWidget);
    // Truck A has two entries, Truck B one.
    expect(find.text('2 inspections'), findsOneWidget);
    expect(find.text('1 inspection'), findsOneWidget);
    // The filter bar counts across all vehicles.
    expect(find.text('3 inspections'), findsOneWidget);
  });

  testWidgets('the Today filter narrows every log to today', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.tap(find.text('Today'));
    await _settle(tester);

    // Truck A's log keeps the one from today; Truck B has none.
    expect(find.text('1 inspection'), findsWidgets);
    expect(find.text('0 inspections'), findsWidgets);
  });

  testWidgets('the type filter narrows to one kind of inspection',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    // The chip row's "Monthly" is the only one at first.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Monthly'));
    await _settle(tester);

    // Only Truck B has a monthly inspection: the bar and Truck B's log both
    // say one, and Truck A's log says none.
    expect(find.text('1 inspection'), findsNWidgets(2));
    expect(find.text('0 inspections'), findsOneWidget);
  });

  testWidgets('a vehicle with no inspections still has a log', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(app(data: const []));
    await _settle(tester);

    expect(find.text('Truck A'), findsOneWidget);
    expect(find.text('Truck B'), findsOneWidget);
    expect(find.text('0 inspections'), findsNWidgets(3)); // two logs + the bar
    expect(find.text('Daily not done today'), findsNWidgets(2));
  });

  testWidgets('with no vehicles it says so', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(app(list: const []));
    await _settle(tester);

    expect(find.text('No vehicles'), findsOneWidget);
  });

  group('shared filter logic for any dated item', () {
    test('applyBy and groupByDay work on plain values', () {
      const filter = InspectionDateFilter.all();
      final dates = [
        DateTime(2026, 11, 3, 8),
        DateTime(2026, 11, 3, 15),
        DateTime(2026, 10, 30, 9),
      ];
      final sorted = filter.applyBy<DateTime>(dates, (d) => d);
      expect(sorted.first, DateTime(2026, 11, 3, 15));

      final groups = filter.groupByDay<DateTime>(sorted, (d) => d);
      expect(groups.map((g) => g.title).toList(),
          ['Tue, Nov 3, 2026', 'Fri, Oct 30, 2026']);
      expect(groups.first.items.length, 2);
    });
  });
}
