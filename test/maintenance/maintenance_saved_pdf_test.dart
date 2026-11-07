import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';

void main() {
  final saved = DateTime(2026, 11, 3, 12);

  group('MaintenanceRepo.isSavedPdfCurrent', () {
    test('a PDF written after the last edit is reused', () {
      expect(
        MaintenanceRepo.isSavedPdfCurrent(
          pdfModified: saved,
          recordUpdated: saved.subtract(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });

    test('a record edited after the PDF was written needs a new PDF', () {
      expect(
        MaintenanceRepo.isSavedPdfCurrent(
          pdfModified: saved,
          recordUpdated: saved.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('a photo added after the PDF was written needs a new PDF', () {
      expect(
        MaintenanceRepo.isSavedPdfCurrent(
          pdfModified: saved,
          recordUpdated: saved.subtract(const Duration(hours: 1)),
          newestPhoto: saved.add(const Duration(seconds: 30)),
        ),
        isFalse,
      );
    });

    test('older photos do not invalidate the PDF', () {
      expect(
        MaintenanceRepo.isSavedPdfCurrent(
          pdfModified: saved,
          recordUpdated: saved.subtract(const Duration(hours: 1)),
          newestPhoto: saved.subtract(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });
  });

  test('the short id matches the one used in report file names', () {
    expect(PdfService.maintenanceShortId('5c73765e-830d-4bf3-873e'), '5c73765e');
    expect(PdfService.maintenanceShortId('abc'), 'abc');
  });
}
