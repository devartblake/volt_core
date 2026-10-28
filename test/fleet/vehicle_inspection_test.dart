import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/core/services/pdf/vehicle_report_data.dart';
import 'package:voltcore/core/services/photos/photo_attachment.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_maintenance_check.dart';

VehicleInspection _inspection(
  InspectionCadence cadence,
  DateTime at, {
  Map<String, CheckStatus>? results,
}) =>
    VehicleInspection.newDraft(vehicleId: 'v1', cadence: cadence).copyWith(
      inspectedAt: at,
      results: results,
    );

void main() {
  final now = DateTime(2026, 6, 15, 12);

  late Directory hiveDir;
  setUpAll(() {
    // The photo appendix reads photo metadata from Hive.
    hiveDir = Directory.systemTemp.createTempSync('voltcore_vehicle_pdf');
    Hive.init(hiveDir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    try {
      hiveDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('InspectionStatus', () {
    test('never when nothing is recorded', () {
      final s = InspectionStatus.compute(InspectionCadence.weekly, const [],
          now: now);
      expect(s.state, InspectionDueState.never);
    });

    test('weekly is ok, due soon, then overdue', () {
      InspectionStatus at(Duration ago) => InspectionStatus.compute(
            InspectionCadence.weekly,
            [_inspection(InspectionCadence.weekly, now.subtract(ago))],
            now: now,
          );
      expect(at(const Duration(days: 2)).state, InspectionDueState.ok);
      expect(at(const Duration(days: 6, hours: 12)).state,
          InspectionDueState.dueSoon);
      expect(at(const Duration(days: 8)).state, InspectionDueState.overdue);
    });

    test('a monthly inspection also satisfies the weekly one, not vice versa',
        () {
      final monthly = [
        _inspection(InspectionCadence.monthly,
            now.subtract(const Duration(days: 1)))
      ];
      final weekly = [
        _inspection(InspectionCadence.weekly,
            now.subtract(const Duration(days: 1)))
      ];
      expect(
        InspectionStatus.compute(InspectionCadence.weekly, monthly, now: now)
            .state,
        InspectionDueState.ok,
      );
      expect(
        InspectionStatus.compute(InspectionCadence.monthly, weekly, now: now)
            .state,
        InspectionDueState.never,
      );
    });
  });

  group('VehicleInspection', () {
    test('monthly checklist extends the weekly one', () {
      expect(inspectionItemsFor(InspectionCadence.monthly).length,
          greaterThan(inspectionItemsFor(InspectionCadence.weekly).length));
    });

    test('round-trips through JSON and counts flagged items', () {
      final original = _inspection(
        InspectionCadence.weekly,
        now,
        results: {
          'tires': CheckStatus.fail,
          'lights': CheckStatus.attention,
          'brakes': CheckStatus.ok,
        },
      ).copyWith(odometer: 1234, notes: 'ok', itemNotes: {'tires': 'bald'});

      final restored = VehicleInspection.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.odometer, 1234);
      expect(restored.issueCount, 2);
      expect(restored.failCount, 1);
      expect(restored.itemNotes['tires'], 'bald');
      expect(restored.results['lights'], CheckStatus.attention);
    });
  });

  test('photo metadata defaults to photo and round-trips video', () {
    final legacy = PhotoAttachment.fromMap({
      'id': 'a',
      'ownerType': 'inspection',
      'ownerId': 'x',
      'localPath': '/p.jpg',
    });
    expect(legacy.isVideo, isFalse);

    final video = PhotoAttachment.fromJson(PhotoAttachment(
      id: 'b',
      ownerType: PhotoAttachment.ownerVehicle,
      ownerId: 'v1',
      localPath: '/v.mp4',
      mediaType: PhotoAttachment.mediaVideo,
    ).toJson());
    expect(video.isVideo, isTrue);
  });

  test('vehicle report builds a non-empty PDF', () async {
    final vehicle = VehicleEntity(
      id: 'v1',
      tenantId: 't',
      designation: 'Truck 7',
      createdAt: now,
      updatedAt: now,
      odometer: 5000,
    );
    final bytes = await PdfService.instance.buildVehiclePdfBytes(
      VehicleReportData(
        vehicle: vehicle,
        driverName: 'Sam',
        inspections: [
          _inspection(InspectionCadence.weekly, now,
              results: {'tires': CheckStatus.fail}),
        ],
        assets: const [
          VehicleReportAsset(label: 'Ladder', status: 'Missing'),
        ],
      ),
    );
    expect(bytes.length, greaterThan(500));
    // A PDF starts with "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
