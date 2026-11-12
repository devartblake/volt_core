import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

// A real 1x1 PNG, so the PDF library can decode it.
final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory dir;

  setUpAll(() {
    // The photo appendix reads photo metadata from Hive.
    dir = Directory.systemTemp.createTempSync('voltcore_maint_sig');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  MaintenanceRecord record() => MaintenanceRecord(id: 'rec-1')
    ..technicianSignatureName = 'Tech'
    ..customerSignatureName = 'Customer';

  test('drawn signatures are embedded in the maintenance PDF', () async {
    final unsigned =
        await PdfService.instance.buildMaintenancePdfBytes(record());

    final signed = record()
      ..technicianSignatureBytes = _png
      ..customerSignatureBytes = _png;
    final withSignatures =
        await PdfService.instance.buildMaintenancePdfBytes(signed);

    // Each embedded image adds an XObject; the unsigned file has none.
    final unsignedImages = RegExp(r'/Subtype\s*/Image')
        .allMatches(latin1.decode(unsigned, allowInvalid: true))
        .length;
    final signedImages = RegExp(r'/Subtype\s*/Image')
        .allMatches(latin1.decode(withSignatures, allowInvalid: true))
        .length;

    expect(signedImages, greaterThan(unsignedImages));
    expect(withSignatures.length, greaterThan(unsigned.length));
  });

  test('a signature saved to disk is read back via the stored path', () async {
    final file = File('${dir.path}/tech.png')..writeAsBytesSync(_png);
    final onDisk = record()..technicianSignaturePath = file.path;

    final bytes = await PdfService.instance.buildMaintenancePdfBytes(onDisk);
    final images = RegExp(r'/Subtype\s*/Image')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;
    expect(images, greaterThanOrEqualTo(1));
  });

  test('report lays out a fully populated record with long text', () async {
    final long = List.filled(60, 'Long observation about the generator.').join(' ');
    final full = record()
      ..siteCode = 'BK-0042'
      ..address = '952 Flushing Ave Suite 3 Brooklyn NY 11206'
      ..technicianName = 'Sam Technician'
      ..dateOfService = DateTime(2026, 10, 30)
      ..batteryNeedsReplace = true
      ..airFilterNeedsReplace = true
      ..coolantHosesCompromised = true
      ..coolantHosesRecommendChange = true
      ..coolantHosesInfo = long
      ..canLube = true
      ..canLubePartNo = 'LF-100'
      ..oilFilterChanged = true
      ..oilFilterNotes = long
      ..serviceObservations = long
      ..requiresFollowUp = true
      ..followUpNotes = long
      ..partsOilTypeQty = long
      ..technicianSignatureBytes = _png
      ..customerSignatureBytes = _png;

    final bytes = await PdfService.instance.buildMaintenancePdfBytes(full);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // Long text must flow onto extra pages rather than being clipped.
    final pages = RegExp(r'/Type\s*/Page[^s]')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;
    expect(pages, greaterThan(1));
  });
}
