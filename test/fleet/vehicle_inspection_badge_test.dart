import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/pending_records.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_detail_page.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_inspection_log_page.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

VehicleEntity _vehicle() => VehicleEntity(
      id: 'v1',
      tenantId: 't',
      designation: 'Truck B',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

VehicleInspection _insp(DateTime at) => VehicleInspection.newDraft(
      vehicleId: 'v1',
      cadence: InspectionCadence.daily,
    ).copyWith(inspectedAt: at, driverName: 'Sam', dispatcherName: 'Dana');

void main() {
  final now = DateTime.now();
  final queued = _insp(DateTime(now.year, now.month, now.day, 9));
  final synced = _insp(DateTime(now.year, now.month, now.day, 8));
  final data = [queued, synced];
  final pending = {'vehicle_inspections/${queued.id}'};

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget wrap(
    Widget home,
    List<Override> overrides, {
    Set<String>? keys,
    double scale = 1,
  }) =>
      ProviderScope(
        overrides: [
          pendingRecordKeysProvider.overrideWith((ref) async => keys ?? pending),
          ...overrides,
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (c, child) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      );

  List<Override> logOverrides() => [
        fleetVisibleVehiclesProvider.overrideWith((ref) async => [_vehicle()]),
        allVehicleInspectionsProvider.overrideWith((ref) async => data),
      ];

  List<Override> detailOverrides() => [
        vehicleProvider('v1').overrideWith((ref) async => _vehicle()),
        fleetManagerProvider.overrideWithValue(true),
        vehicleInspectionsProvider('v1').overrideWith((ref) async => data),
        vehicleChecksProvider('v1').overrideWith((ref) async => const []),
        fleetAssignableMembersProvider.overrideWith((ref) async => const []),
        vehicleAssetsProvider('v1').overrideWith((ref) async => const []),
        vehicleDocumentsProvider('v1').overrideWith((ref) async => const []),
      ];

  testWidgets('log: badge only on the queued inspection, 1.3x no overflow',
      (tester) async {
    size(tester);
    await tester.pumpWidget(
        wrap(const VehicleInspectionLogPage(), logOverrides(), scale: 1.3));
    await _settle(tester);

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('log: no badge when nothing is queued', (tester) async {
    size(tester);
    await tester.pumpWidget(wrap(
        const VehicleInspectionLogPage(), logOverrides(),
        keys: <String>{}));
    await _settle(tester);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('log: another table with the same id does not badge',
      (tester) async {
    size(tester);
    await tester.pumpWidget(wrap(
        const VehicleInspectionLogPage(), logOverrides(),
        keys: {'maintenance_records/${queued.id}'}));
    await _settle(tester);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('vehicle detail Inspections tab: badge only on queued row',
      (tester) async {
    size(tester);
    await tester.pumpWidget(
        wrap(const VehicleDetailPage(id: 'v1'), detailOverrides(), scale: 1.3));
    await _settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(TabBar), matching: find.textContaining('Inspections')));
    await _settle(tester);

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
