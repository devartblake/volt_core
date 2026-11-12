import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_inspection_form_page.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_inspection_log_page.dart';
import 'package:voltcore/modules/inspections/presenter/inspection_date_filter.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/inspection_date_filter_bar.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/controllers/schedule_controller.dart';
import 'package:voltcore/modules/schedule/presenter/pages/schedule_task_detail_page.dart';
import 'package:voltcore/shared/presenter/widgets/sync_status_indicator.dart';
import 'package:voltcore/shared/widgets/widgets.dart';

/// Users raise the system font size; at 1.3x nothing should overflow or clip.
///
/// A RenderFlex overflow is reported as a test exception, so each case just
/// pumps the screen at 1.3x on a phone-sized and a tablet-sized window and
/// checks that nothing was thrown.
const _scale = 1.3;

const _sizes = <String, Size>{
  'phone': Size(360, 800),
  'tablet portrait': Size(800, 1280),
  'tablet landscape': Size(1280, 800),
};

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Widget _scaled(Widget home) => MaterialApp(
      theme: ThemeData(extensions: const [StatusColors.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(_scale)),
        child: child!,
      ),
      home: home,
    );

/// Fails with the full widget chain of any layout error, so the offending
/// widget is named in the output.
void _clean(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    fail(_reports.isEmpty ? '$error' : _reports.join('\n---\n'));
  }
}

final _reports = <String>[];

void _size(WidgetTester tester, Size size) {
  _reports.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _reports.add(details.toString());
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late Directory dir;
  late Box<String> box;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_text_scale');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('text_scale_inspections');
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
    designation: 'Truck with a fairly long designation',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    odometer: 1000,
  );

  for (final entry in _sizes.entries) {
    group('1.3x text on ${entry.key}', () {
      testWidgets('shared components', (tester) async {
        _size(tester, entry.value);
        await tester.pumpWidget(_scaled(Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const StatusChip(
                  label: 'Out of service for repairs',
                  tone: StatusTone.danger,
                  icon: Icons.build,
                ),
                const SizedBox(height: 8),
                const InfoChip(
                  icon: Icons.place_outlined,
                  label: 'A very long address that keeps going and going',
                  filled: true,
                ),
                const SizedBox(height: 8),
                // Grid cells are fixed-ratio, which is where scaling bites.
                SizedBox(
                  height: 120,
                  width: 170,
                  child: StatCard.tile(
                    icon: Icons.fact_check_outlined,
                    label: 'With deficiencies',
                    value: '1,284',
                  ),
                ),
                const SizedBox(height: 8),
                const Row(children: [
                  Expanded(
                    child: StatCard(
                      compact: true,
                      icon: Icons.list_alt,
                      label: 'Pending',
                      value: '128',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      compact: true,
                      icon: Icons.warning_amber_rounded,
                      label: 'Amber',
                      value: '7',
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 260,
                  child: StatCard(
                    horizontal: true,
                    icon: Icons.build_outlined,
                    label: 'Open Maintenance Jobs',
                    value: '42',
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No inspections yet',
                    message: 'Inspections you create will appear here.',
                  ),
                ),
              ],
            ),
          ),
        )));
        await tester.pump();
        _clean(tester);
      });

      testWidgets('sync indicator meets the 48 dp tap target', (tester) async {
        _size(tester, entry.value);
        await tester.pumpWidget(_scaled(const Scaffold(
          body: Center(child: SyncStatusIndicator(compact: false)),
        )));
        await tester.pump();
        _clean(tester);

        final size = tester.getSize(find.byType(InkWell).first);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });

      testWidgets('date filter bar', (tester) async {
        _size(tester, entry.value);
        await tester.pumpWidget(_scaled(Scaffold(
          body: InspectionDateFilterBar(
            filter: const InspectionDateFilter.all(),
            onChanged: (_) {},
            shown: 12,
            total: 128,
          ),
        )));
        await tester.pump();
        _clean(tester);
      });

      testWidgets('vehicle inspection log', (tester) async {
        _size(tester, entry.value);
        final inspections = [
          VehicleInspection.newDraft(
                  vehicleId: 'veh-1', cadence: InspectionCadence.daily)
              .copyWith(driverName: 'Sam', dispatcherName: 'Dana'),
        ];
        await tester.pumpWidget(ProviderScope(
          overrides: [
            fleetVisibleVehiclesProvider.overrideWith((ref) async => [vehicle]),
            allVehicleInspectionsProvider
                .overrideWith((ref) async => inspections),
          ],
          child: _scaled(const VehicleInspectionLogPage()),
        ));
        await _settle(tester);
        _clean(tester);
      });

      testWidgets('daily vehicle inspection form', (tester) async {
        _size(tester, entry.value);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            vehicleProvider('veh-1').overrideWith((ref) async => vehicle),
            vehicleInspectionRepositoryProvider
                .overrideWithValue(VehicleInspectionRepository(box: box)),
          ],
          child: _scaled(const VehicleInspectionFormPage(
            vehicleId: 'veh-1',
            cadence: InspectionCadence.daily,
          )),
        ));
        await _settle(tester);
        _clean(tester);
      });

      testWidgets('schedule task detail', (tester) async {
        _size(tester, entry.value);
        final task = TaskScheduleEntity(
          id: 'schedule-1',
          scheduledAt: DateTime.utc(2026, 8, 25, 9),
          scheduledDate: DateTime.utc(2026, 8, 25),
          createdAt: DateTime.utc(2026, 8, 20),
          updatedAt: DateTime.utc(2026, 8, 20),
          title: 'Generator maintenance',
          description: 'Quarterly load test',
          sourceType: 'maintenance_record',
          sourceId: 'maintenance-record-1',
          siteCode: 'Q844',
          address: '952 Flushing Ave, Brooklyn NY 11206',
          status: 'scheduled',
        );
        await tester.pumpWidget(ProviderScope(
          overrides: [
            scheduleTaskProvider(task.id).overrideWith((ref) async => task),
          ],
          child: _scaled(const ScheduleTaskDetailPage(id: 'schedule-1')),
        ));
        await _settle(tester);
        _clean(tester);
      });
    });
  }
}
