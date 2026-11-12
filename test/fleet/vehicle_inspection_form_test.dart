import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_inspection_form_page.dart';

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late Directory dir;
  late Box<String> box;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_insp_form');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('vehicle_inspections_form_test');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final vehicle = VehicleEntity(
    id: 'veh-1',
    tenantId: 't',
    designation: 'Truck B',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    odometer: 1000,
  );

  Widget app(InspectionCadence cadence) => ProviderScope(
        overrides: [
          vehicleProvider('veh-1').overrideWith((ref) async => vehicle),
          vehicleInspectionRepositoryProvider
              .overrideWithValue(VehicleInspectionRepository(box: box)),
        ],
        child: MaterialApp(
          home: VehicleInspectionFormPage(
            vehicleId: 'veh-1',
            cadence: cadence,
          ),
        ),
      );

  testWidgets('saving a blank daily inspection opens the missing-items dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(InspectionCadence.daily));
    await _settle(tester);

    // Nothing is pre-answered, and all four photo boxes are there.
    expect(find.text('0 of 14 answered'), findsOneWidget);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Driver side'), findsOneWidget);
    expect(find.text('Passenger side'), findsOneWidget);

    await tester.tap(find.byTooltip('Complete inspection'));
    await _settle(tester);

    expect(find.text('Inspection not complete'), findsOneWidget);
    expect(find.textContaining('Photo: Front of the vehicle'), findsOneWidget);
    expect(find.textContaining('Photo: Passenger side of the vehicle'),
        findsOneWidget);
    expect(find.textContaining("Assigned person's signature"), findsOneWidget);
    expect(find.textContaining("Dispatcher's signature"), findsOneWidget);

    // Nothing was saved.
    expect(box.isEmpty, isTrue);

    // The dialog can be dismissed to keep editing.
    await tester.tap(find.text('Go back and fix'));
    await _settle(tester);
    expect(find.text('Inspection not complete'), findsNothing);
  });

  testWidgets('answering every question removes those items from the list',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(InspectionCadence.daily));
    await _settle(tester);

    // Tap OK on every question.
    final ok = find.text('OK');
    final count = ok.evaluate().length;
    expect(count, 14);
    for (var i = 0; i < count; i++) {
      await tester.tap(find.text('OK').at(i));
      await tester.pump();
    }
    expect(find.text('14 of 14 answered'), findsOneWidget);

    await tester.tap(find.byTooltip('Complete inspection'));
    await _settle(tester);

    expect(find.text('Inspection not complete'), findsOneWidget);
    expect(find.textContaining('Answer:'), findsNothing);
    // Photos and signatures are still outstanding.
    expect(find.textContaining('Photo: Back of the vehicle'), findsOneWidget);
    expect(find.textContaining("Assigned person's name"), findsOneWidget);
    expect(box.isEmpty, isTrue);
  });
}
