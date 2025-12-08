import '../../domain/entities/inspection_entity.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/storage/export_service.dart';
import '../../infra/mappers/inspection_mapper.dart';

class InspectionPdfDriver {
  final PdfService pdfService;
  final PdfPrefsService prefsService;
  final EmailService emailService;
  final ExportService exportService;

  InspectionPdfDriver({
    required this.pdfService,
    required this.prefsService,
    required this.emailService,
    required this.exportService,
  });

  /// Generates the PDF for the given inspection, performs export/email based
  /// on prefs, and returns an updated entity with [pdfPath] set.
  Future<InspectionEntity> generateAndExport(
      InspectionEntity inspection,
      ) async {
    // Load per-device preferences
    final emailAllowed = await prefsService.getEmailAllowed();
    final customDir = await prefsService.getCustomDirectoryPath();
    final defaultRecipient = await prefsService.getDefaultRecipient();

    final exportPrefs = PdfExportPrefs(
      emailAllowed: emailAllowed,
      customDirectoryPath: customDir,
      defaultRecipient: defaultRecipient,
      appSubfolder: 'AandSElectric/Inspections',
    );

    // NOTE: if PdfService only knows about your old infra model, you’ll need
    // a simple mapper: InspectionEntity → Inspection (Hive model).
    // I’ll assume you already have something like `InspectionMapper`.
    final infraModel = InspectionMapper.fromEntity(inspection);

    // Generate PDF (and maybe email/export inside PdfService or here)
    final pdfPath = await pdfService.generatePdfForInspection(
      infraModel,
      prefs: exportPrefs,
      // templateAsset: 'assets/pdf/Modified Comp Checklist With Load Test.pdf',
    );

    // Optionally call exportService.tryCopyToExternal(...) and/or
    // emailService.sendInspectionPdf(...) here if not already done in PdfService.

    return inspection.copyWith(pdfPath: pdfPath);
  }
}
