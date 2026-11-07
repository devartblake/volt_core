import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/core/services/pdf/vehicle_report_data.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';

// A real 1x1 PNG, so the PDF library can decode it.
final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

int _images(List<int> pdf) => RegExp(r'/Subtype\s*/Image')
    .allMatches(latin1.decode(pdf, allowInvalid: true))
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('voltcore_vehicle_media');
    Hive.init(dir.path);
  });
  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final now = DateTime(2026, 6, 15, 12);
  final vehicle = VehicleEntity(
    id: 'v1',
    tenantId: 't',
    designation: 'Truck 7',
    createdAt: now,
    updatedAt: now,
    odometer: 5000,
  );
  final inspection =
      VehicleInspection.newDraft(vehicleId: 'v1', cadence: InspectionCadence.daily)
          .copyWith(inspectedAt: now);

  VehicleReportData data({
    bool media = false,
    String? driverPath,
  }) =>
      VehicleReportData(
        vehicle: vehicle,
        inspections: [
          if (driverPath != null)
            inspection.copyWith(driverSignaturePath: driverPath)
          else
            inspection,
        ],
        driverSignature: media ? _png : null,
        dispatcherSignature: media ? _png : null,
        vehiclePhotos:
            media ? [VehicleReportPhoto(bytes: _png, caption: 'Front')] : const [],
        inspectionPhotos:
            media ? [VehicleReportPhoto(bytes: _png, caption: 'Dash')] : const [],
      );

  test('signatures and photos are embedded in the vehicle PDF', () async {
    final plain = await PdfService.instance.buildVehiclePdfBytes(data());
    final full = await PdfService.instance.buildVehiclePdfBytes(data(media: true));

    expect(String.fromCharCodes(full.take(4)), '%PDF');
    expect(full, isNotEmpty);
    expect(_images(full), greaterThan(_images(plain)));
    expect(full.length, greaterThan(plain.length));
  });

  test('a signature saved on disk is read back via the stored path', () async {
    final file = File('${dir.path}/driver.png')..writeAsBytesSync(_png);
    final plain = await PdfService.instance.buildVehiclePdfBytes(data());
    final bytes = await PdfService.instance
        .buildVehiclePdfBytes(data(driverPath: file.path));
    expect(_images(bytes), greaterThan(_images(plain)));
  });

  test('an undecodable photo does not break the report', () async {
    final bytes = await PdfService.instance.buildVehiclePdfBytes(
      VehicleReportData(
        vehicle: vehicle,
        inspections: [inspection],
        vehiclePhotos: [VehicleReportPhoto(bytes: _png.sublist(0, 20))],
      ),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
