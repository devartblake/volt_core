import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/modules/fleet/domain/daily_check_status.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';

VehicleInspection _at(InspectionCadence cadence, DateTime at) =>
    VehicleInspection.newDraft(vehicleId: 'v1', cadence: cadence)
        .copyWith(inspectedAt: at);

void main() {
  final now = DateTime(2026, 6, 15, 14);

  group('dailyCheckState', () {
    test('never checked is due', () {
      expect(dailyCheckState(const [], now: now), DailyCheckState.due);
    });

    test('a daily check earlier today is done', () {
      final list = [_at(InspectionCadence.daily, DateTime(2026, 6, 15, 6))];
      expect(dailyCheckState(list, now: now), DailyCheckState.doneToday);
    });

    test('a weekly walk-around today also counts', () {
      final list = [_at(InspectionCadence.weekly, DateTime(2026, 6, 15, 7))];
      expect(dailyCheckState(list, now: now), DailyCheckState.doneToday);
    });

    test('last check yesterday is due, not overdue', () {
      final list = [_at(InspectionCadence.daily, DateTime(2026, 6, 14, 23))];
      expect(dailyCheckState(list, now: now), DailyCheckState.due);
    });

    test('two or more days without a check is overdue', () {
      final list = [_at(InspectionCadence.daily, DateTime(2026, 6, 13, 9))];
      expect(dailyCheckState(list, now: now), DailyCheckState.overdue);
    });

    test('order does not matter', () {
      final list = [
        _at(InspectionCadence.daily, DateTime(2026, 6, 1)),
        _at(InspectionCadence.daily, DateTime(2026, 6, 15, 8)),
        _at(InspectionCadence.daily, DateTime(2026, 6, 10)),
      ];
      expect(dailyCheckState(list, now: now), DailyCheckState.doneToday);
    });
  });

  group('vehicleDocumentsFor', () {
    PdfDocumentInfo doc(String name, PdfCategory c, int day) => PdfDocumentInfo(
          path: '/pdfs/vehicles/$name',
          name: name,
          category: c,
          sizeBytes: 10,
          modified: DateTime(2026, 6, day),
        );

    test('keeps only this vehicle\'s vehicle PDFs, newest first', () {
      final docs = [
        doc('Vehicle_Truck_B_2026-06-01_abcdef12.pdf', PdfCategory.vehicle, 1),
        doc('Vehicle_Truck_B_2026-06-09_abcdef12.pdf', PdfCategory.vehicle, 9),
        doc('Vehicle_Van_2026-06-05_99999999.pdf', PdfCategory.vehicle, 5),
        doc('Maintenance_abcdef12.pdf', PdfCategory.maintenance, 7),
      ];
      final out = vehicleDocumentsFor(docs, 'abcdef12-3456-7890');
      expect(out.map((d) => d.name), [
        'Vehicle_Truck_B_2026-06-09_abcdef12.pdf',
        'Vehicle_Truck_B_2026-06-01_abcdef12.pdf',
      ]);
    });

    test('empty id matches nothing', () {
      expect(vehicleDocumentsFor(const [], ''), isEmpty);
    });
  });
}
