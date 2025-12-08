import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/storage/export_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/hive/hive_boxes.dart';

import '../../infra/models/inspection.dart';

/// Driver responsible for:
///  - saving inspection to Hive
///  - generating PDF
///  - exporting to external storage
///  - emailing PDF
///
/// This is your old `InspectionRepo` logic, but wrapped in a
/// focused driver so the domain repository can stay clean.
class InspectionExportDriver {
  InspectionExportDriver({
    PdfService? pdf,
    EmailService? email,
    ExportService? export,
  })  : _pdf = pdf ?? PdfService.instance,
        _email = email ?? EmailService(),
        _export = export ?? ExportService();

  final PdfService _pdf;
  final EmailService _email;
  final ExportService _export;

  /// Save to Hive, generate PDF, export & email.
  Future<void> saveAndExport(
      Inspection inspection,
      BuildContext context,
      ) async {
    // Ensure ID
    inspection.id =
    inspection.id.isEmpty ? const Uuid().v4() : inspection.id;

    // Save to Hive
    await HiveBoxes.inspections.put(inspection.id, inspection);

    // Build PDF (returns file path)
    final pdfPath = await _pdf.generatePdfForInspection(
      inspection,
      templateAsset:
      'assets/pdf/Modified Comp Checklist With Load Test.pdf',
    );

    inspection.pdfPath = pdfPath;
    await inspection.save();

    // Optional: copy to external/microSD (Android)
    await _export.tryCopyToExternal(inspection);

    // Email
    await _email.sendInspectionPdf(inspection, pdfPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved, PDF generated & emailed.'),
        ),
      );
    }
  }

  /// Export a PDF for an existing inspection using PdfPrefsService prefs.
  Future<void> exportInspectionPdf(Inspection inspection) async {
    final prefsService = PdfPrefsService.instance;
    final emailAllowed = await prefsService.getEmailAllowed();
    final customDir = await prefsService.getCustomDirectoryPath();
    final defaultRecipient = await prefsService.getDefaultRecipient();

    final exportPrefs = PdfExportPrefs(
      emailAllowed: emailAllowed,
      customDirectoryPath: customDir,
      defaultRecipient: defaultRecipient,
      appSubfolder: 'AandSElectric/Inspections',
    );

    await PdfService.instance.generatePdfForInspection(
      inspection,
      prefs: exportPrefs,
    );
  }
}

/// Riverpod provider for the export driver.
///
/// Use this in UI when you want to:
///  - Save + generate PDF + email
///  - Re-export a PDF
final inspectionExportDriverProvider =
Provider<InspectionExportDriver>((ref) {
  return InspectionExportDriver();
});
