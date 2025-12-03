import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../email/email_service.dart';
import '../../../../pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../storage/export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inspection.dart';
import '../sources/hive_boxes.dart';

final inspectionRepoProvider = Provider(
  (ref) => InspectionRepo(
    pdf: PdfService.instance,
    email: EmailService(),
    export: ExportService(),
  ),
);

class InspectionRepo {
  InspectionRepo({
    required this.pdf,
    required this.email,
    required this.export,
  });
  final PdfService pdf;
  final EmailService email;
  final ExportService export;

  Future<void> saveAndExport(Inspection ins, BuildContext context) async {
    ins.id = ins.id.isEmpty ? const Uuid().v4() : ins.id;
    await HiveBoxes.inspections.put(ins.id, ins);
    // Build PDF (returns file path)
    final pdfPath = await pdf.generatePdfForInspection(
      ins,
      templateAsset: 'assets/pdf/Modified Comp Checklist With Load Test.pdf',
    ); // place your PDF in assets
    ins.pdfPath = pdfPath;
    await ins.save();

    // Optional: copy to external/microSD (Android)
    await export.tryCopyToExternal(ins);

    // Email
    await email.sendInspectionPdf(ins, pdfPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved, PDF generated & emailed.')),
      );
    }
  }

  Future<void> exportInspectionPdf(Inspection inspection) async {
    // Load Hive-backed prefs (per device)
    final prefsService = PdfPrefsService.instance;
    final emailAllowed = await prefsService.getEmailAllowed();
    final customDir = await prefsService.getCustomDirectoryPath();
    final defaultRecipient = await prefsService.getDefaultRecipient();

    final exportPrefs = PdfExportPrefs(
      emailAllowed: emailAllowed,
      customDirectoryPath: customDir,
      defaultRecipient: defaultRecipient,
      // appSubfolder can be whatever you used before
      appSubfolder: 'AandSElectric/Inspections',
    );

    // If your PdfService.generatePdfForInspection already saves files
    // AND optionally emails based on prefs, just pass the prefs in:
    await PdfService.instance.generatePdfForInspection(
      inspection,
      prefs: exportPrefs,
    );

    // If instead generatePdfForInspection ONLY returns a path,
    // then you would manually call PdfService.instance.saveAndMaybeEmail(...)
    // here. But based on your previous code, you already have
    // `_saveAndMaybeEmailPdf` inside PdfService and call it there.
  }

  List<Inspection> listAll() =>
      HiveBoxes.inspections.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
