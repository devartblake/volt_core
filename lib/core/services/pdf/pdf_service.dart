import 'dart:io' as io;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

//
// import '../../features/inspections/data/models/inspection.dart';
// import '../../features/inspections/data/models/load_test_record.dart';
// import '../../features/inspections/data/models/nameplate_data.dart';
// import '../../features/inspections/data/models/test_interval_record.dart';
// import '../../features/inspections/data/sources/hive_boxes.dart';
// import '../../features/maintenance/data/models/maintenance_record.dart';
import '../../../modules/fleet/domain/entities/vehicle_entity.dart';
import '../../../modules/fleet/domain/entities/vehicle_inspection.dart';
import '../../../modules/fleet/domain/entities/vehicle_maintenance_check.dart';
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';
import '../../../modules/maintenance/infra/models/maintenance_record.dart';
import '../../../shared/presenter/layout/pdf/pdf_template.dart';
import '../../services/hive/hive_boxes.dart';
import '../photos/photo_attachment.dart';
import 'maintenance_report_pdf.dart';
import 'pdf_prefs_service.dart';
import 'vehicle_report_data.dart';
import '../photos/photo_service.dart';
import '../storage/file_storage_service.dart';
import '../storage/path_resolver.dart';
import '../storage/web_file_store.dart';
import '../sync/sync_service.dart';

/// User-level preferences for how PDFs should be exported.
///
/// You will typically build this from a Hive-backed service
/// (e.g. `EmailPrefsService`) *outside* of this file.
class PdfExportPrefs {
  /// Whether the user has explicitly allowed the app to open the
  /// default email/share sheet with the generated PDF.
  final bool emailAllowed;

  /// Optional default email recipient (e.g., your office address).
  final String? defaultRecipient;

  /// Optional directory chosen by the user; if null we'll use an
  /// app-specific directory from `path_provider`.
  final String? customDirectoryPath;

  /// An app-subfolder name for PDFs (e.g., "AandSElectric/PDFs").
  final String appSubfolder;

  const PdfExportPrefs({
    required this.emailAllowed,
    this.defaultRecipient,
    this.customDirectoryPath,
    this.appSubfolder = 'AandSElectric/PDFs',
  });
}

class PdfExportResult {
  final String? filePath;
  final bool emailed;

  const PdfExportResult({this.filePath, this.emailed = false});
}

/// Central service for generating and exporting PDFs.
///
/// API is kept backward-compatible:
/// - `PdfService.instance` singleton is preserved.
/// - Existing method names are kept; only *optional* named params added.
class PdfService {
  PdfService._();

  static final PdfService _instance = PdfService._();
  static PdfService get instance => _instance;

  /// Generate an inspection PDF, save it under an app directory,
  /// and *optionally* open the platform share/email sheet
  /// if `prefs.emailAllowed == true`.
  ///
  /// Returns the local file path (or empty string on web/if failed).
  Future<String> generatePdfForInspection(
    Inspection ins, {
    PdfExportPrefs? prefs,
    String? templateAsset,
  }) async {
    final bytes = await _buildInspectionPdfBytes(ins);

    // SiteCode_YYYY-MM-DD (same convention you were using)
    final siteCode = ins.siteCode.isNotEmpty
        ? ins.siteCode.replaceAll(RegExp(r'[^\w\-]'), '_')
        : 'NO_SITE_CODE';
    final dateStr = ins.serviceDate.toIso8601String().split('T').first;
    final folderName = '${siteCode}_$dateStr';

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Relative path inside the app PDF tree:
    //   <appDir>/<appSubfolder>/inspections/<Site_Date>/inspection_<ts>.pdf
    final relativeFileName = p.join(
      'inspections',
      folderName,
      'inspection_$timestamp.pdf',
    );

    final result = await _saveAndMaybeEmailPdf(
      bytes: bytes,
      fileName: relativeFileName,
      prefs: prefs ?? const PdfExportPrefs(emailAllowed: false),
    );

    debugPrint(
      'Inspection PDF saved to: ${result.filePath ?? '(no local path)'}',
    );
    return result.filePath ?? '';
  }

  /// Public entry to the inspection renderer, for tests and callers that
  /// store the bytes themselves.
  ///
  /// [includeSummary] adds the optional Inspection Summary page; when null
  /// the device setting decides.
  Future<Uint8List> buildInspectionPdfBytes(
    Inspection ins, {
    bool? includeSummary,
  }) =>
      _buildInspectionPdfBytes(ins, includeSummary: includeSummary);

  /// Build the inspection PDF as raw bytes.
  ///
  /// Used internally by [generatePdfForInspection], but you can also call it
  /// directly if you need to do custom storage controllers.
  Future<Uint8List> _buildInspectionPdfBytes(
    Inspection ins, {
    bool? includeSummary,
  }) async {
    // Load fonts
    final baseFont = await rootBundle.load(
      'assets/fonts/NotoSans/NotoSans-Regular.ttf',
    );
    final boldFont = await rootBundle.load(
      'assets/fonts/NotoSans/NotoSans-Bold.ttf',
    );

    // Try to load logo each time (in case it wasn't loaded during init)
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/company_logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo not found, using placeholder: $e');
      logo = null;
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(baseFont),
        bold: pw.Font.ttf(boldFont),
      ),
    );

    // Page 1: Site and Generator Information
    pdf.addPage(_buildPage1(ins, logo));

    // Page 2: Fuel Storage, DEP, Operational
    pdf.addPage(_buildPage2(ins));

    // Page 3: Post-Inspection, Parts, Signatures
    pdf.addPage(_buildPage3(ins));

    // Full notes when they don't fit the fixed box on page 2, so nothing the
    // technician typed is cut off.
    if (_notesOverflow(ins.notes)) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pw.Text(
              'Additional Notes',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(ins.notes.trim(), style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    // Page 4: Detailed Information & Fuel Monitoring
    pdf.addPage(_buildPage4(ins));

    // Page 5: Load Test Table
    pdf.addPage(_buildPage5(ins));

    // NAMEPLATE SUMMARY (one compact page)
    final nameplate = HiveBoxes.nameplates.values
        .where((n) => n.inspectionId == ins.id)
        .cast<NameplateData?>()
        .firstWhere((_) => true, orElse: () => null);

    if (nameplate != null) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pw.Text(
              'Nameplate Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _nameplateSummaryTable(nameplate),
          ],
        ),
      );
    }

    // TEST READING INTERVALS (tabular across pages)
    final intervals =
        HiveBoxes.testIntervals.values
            .where((r) => r.inspectionId == ins.id)
            .cast<TestIntervalRecord>()
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));

    if (intervals.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pw.Text(
              'Test Reading Intervals',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _intervalsTable(intervals),
          ],
        ),
      );
    }

    // LOAD TEST RESULTS
    final loadRows =
        HiveBoxes.loadTests.values
            .where((r) => r.inspectionId == ins.id)
            .cast<LoadTestRecord>()
            .toList()
          ..sort((a, b) => a.stepIndex.compareTo(b.stepIndex));

    if (loadRows.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pw.Text(
              'Load Test Results',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildLoadTestTable(loadRows),
          ],
        ),
      );
    }

    // PHOTO APPENDIX (attached inspection photos, if any)
    await _addPhotosAppendix(pdf, PhotoAttachment.ownerInspection, ins.id);

    // OPTIONAL closing summary (off unless asked for or enabled in Settings).
    var wantSummary = includeSummary;
    if (wantSummary == null) {
      try {
        wantSummary = await PdfPrefsService.instance.getIncludeInspectionSummary();
      } catch (_) {
        wantSummary = false;
      }
    }
    if (wantSummary) pdf.addPage(_buildInspectionSummaryPage(ins));

    return pdf.save();
  }

  /// Append a "Photos" page listing any photos attached to the record.
  ///
  /// No-op when there are no readable photos. Failures are swallowed so photo
  /// issues never prevent report generation.
  Future<void> _addPhotosAppendix(
    pw.Document pdf,
    String ownerType,
    String ownerId,
  ) async {
    if (ownerId.isEmpty) return;

    List<PhotoAttachment> photos;
    try {
      photos = await PhotoService.instance.listForOwner(ownerType, ownerId);
    } catch (_) {
      return;
    }
    photos = photos.where((ph) => !ph.isVideo).toList();
    if (photos.isEmpty) return;

    final items = <_PdfPhoto>[];
    for (final photo in photos) {
      try {
        // Cross-platform read: WebFileStore on web, filesystem on native.
        final bytes = await PhotoService.instance.loadBytes(photo);
        if (bytes == null) continue;
        items.add(_PdfPhoto(pw.MemoryImage(bytes), photo.caption));
      } catch (_) {
        // Skip unreadable images.
      }
    }
    if (items.isEmpty) return;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(
            'Photos',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                pw.Container(
                  width: 240,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(
                        item.image,
                        width: 240,
                        height: 180,
                        fit: pw.BoxFit.cover,
                      ),
                      if (item.caption.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          item.caption,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the maintenance PDF and return bytes (for saving/emailing/etc.)
  Future<Uint8List> buildMaintenancePdfBytes(MaintenanceRecord m) async {
    final pdf = pw.Document();

    final techSignature = await _loadMaintenanceSignature(m, 'technician');
    final customerSignature = await _loadMaintenanceSignature(m, 'customer');

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/company_logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logo = null; // The template draws a text mark when there is no logo.
    }

    MaintenanceReportPdf.addTo(
      pdf,
      m,
      logo: logo,
      technicianSignature: techSignature,
      customerSignature: customerSignature,
    );

    // PHOTO APPENDIX (attached maintenance photos, if any)
    await _addPhotosAppendix(pdf, PhotoAttachment.ownerMaintenance, m.id);

    return pdf.save();
  }

  /// Backward-compatible wrapper you can call from `MaintenanceRepo.exportPdf(rec)`.
  ///
  /// - Saves the PDF under an app folder.
  /// - Optionally opens share/email sheet if [prefs.emailAllowed] is true.
  /// - Copies signature images (if you wire those fields in the model).
  Future<PdfExportResult> generateMaintenancePdf(
    MaintenanceRecord m, {
    PdfExportPrefs? prefs,
  }) async {
    final bytes = await buildMaintenancePdfBytes(m);
    final fileName = p.join('maintenance', _buildMaintenanceFileName(m));
    final effectivePrefs = prefs ?? const PdfExportPrefs(emailAllowed: false);

    final result = await _saveAndMaybeEmailPdf(
      bytes: bytes,
      fileName: fileName,
      prefs: effectivePrefs,
    );

    if (result.filePath != null) {
      final folder = p.dirname(result.filePath!);
      await _copySignaturesIfAny(maintenance: m, folderPath: folder);
    }

    return result;
  }

  String _buildMaintenanceFileName(MaintenanceRecord m) {
    final site = (m.siteCode.isNotEmpty ? m.siteCode : 'maintenance')
        .replaceAll(' ', '_');
    final date = _fmtDate(m.dateOfService ?? m.createdAt);
    // The id suffix keeps two records for the same site on the same day from
    // overwriting each other's report.
    final shortId = m.id.length > 8 ? m.id.substring(0, 8) : m.id;
    return 'Maintenance_${site}_${date}_$shortId.pdf';
  }

  /// PAGE 1: Site and Generator Information, Location & Safety
  pw.Page _buildPage1(Inspection ins, pw.MemoryImage? logo) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfTemplate.pageFooter(
        context.pageNumber,
        total: context.pagesCount,
      ),
      build: (context) => [
          PdfTemplate.companyHeader(logo: logo),
          pw.SizedBox(height: 8),
          PdfTemplate.documentTitle('Generator Compliance Checklist'),
          pw.SizedBox(height: 8),

          // Site And Generator Information
          PdfTemplate.sectionHeader('Site And Generator Information'),
          pw.SizedBox(height: 8),
          // Site Grade with checkboxes
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              children: [
                pw.Text(
                  'Site Grade (Load Testing): ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                PdfTemplate.checkboxWithLabel(
                  'Green',
                  ins.siteGrade == 'Green',
                ),
                pw.SizedBox(width: 12),
                PdfTemplate.checkboxWithLabel(
                  'Amber',
                  ins.siteGrade == 'Amber',
                ),
                pw.SizedBox(width: 12),
                PdfTemplate.checkboxWithLabel('Red', ins.siteGrade == 'Red'),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          PdfTemplate.formFieldsTable({
            'Site Code': ins.siteCode,
            'Address': ins.formattedAddress,
            'Date of Service': _formatDate(ins.serviceDate),
            'Technician Name': ins.technicianName,
            'Generator Make': ins.generatorMake,
            'Generator Model': ins.generatorModel,
            'Generator Serial #': ins.generatorSerial,
            'Generator KW': ins.generatorKw,
            'Engine Hours': ins.engineHours,
            'Fuel Type': ins.fuelType,
            'Voltage Rating': ins.voltageRating,
          }),
          pw.SizedBox(height: 16),

          // Location and Safety
          PdfTemplate.sectionHeader('Location and Safety'),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Generator Location: ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    PdfTemplate.locationCheckboxes(
                      indoors: ins.locIndoors,
                      outdoors: ins.locOutdoors,
                      roof: ins.locRoof,
                      basement: ins.locBasement,
                      other: ins.locOther,
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                _yesNoQuestion(
                  'Is the generator housed in a dedicated room with a 2-hour fire-resistance rating?',
                  ins.dedicatedRoom2hr,
                ),
                pw.SizedBox(height: 8),
                _yesNoQuestion(
                  'Is the generator room separate from the building\'s main electrical service?',
                  ins.separateFromMainService,
                ),
                pw.SizedBox(height: 8),
                _yesNoQuestion(
                  'Is the area around the generator clear of hazards and obstructions?',
                  ins.areaClear,
                ),
                pw.SizedBox(height: 8),
                _yesNoQuestion(
                  'Are warning labels and emergency stop buttons clearly visible?',
                  ins.labelsAndEStopVisible,
                ),
                pw.SizedBox(height: 8),
                _yesNoQuestion(
                  'Is a fire extinguisher present near the generator?',
                  ins.extinguisherPresent,
                ),
              ],
            ),
          ),
    ],
    );
  }

  /// PAGE 2: Fuel Storage, DEP, Operational Use
  pw.Page _buildPage2(Inspection ins) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfTemplate.pageFooter(
        context.pageNumber,
        total: context.pagesCount,
      ),
      build: (context) => [
          // Fuel Storage & FDNY Compliance
          PdfTemplate.sectionHeader('Fuel Storage & FDNY Compliance'),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Type of fuel stored on-site: ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    PdfTemplate.checkboxWithLabel(
                      'Diesel',
                      ins.fuelStoredType == 'Diesel',
                    ),
                    pw.SizedBox(width: 8),
                    PdfTemplate.checkboxWithLabel(
                      'Gasoline',
                      ins.fuelStoredType == 'Gasoline',
                    ),
                    pw.SizedBox(width: 8),
                    PdfTemplate.checkboxWithLabel(
                      'None',
                      ins.fuelStoredType == 'None',
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Approximate quantity of fuel stored: ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    PdfTemplate.inputField(ins.fuelQtyGallons, width: 50),
                    pw.SizedBox(width: 4),
                    pw.Text('gallons', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 12),
                _yesNoUnknownQuestion(
                  'Is there an FDNY permit for flammable/combustible liquids?',
                  ins.fdnyPermit,
                ),
                pw.SizedBox(height: 8),
                _yesNoUnknownQuestion(
                  'Is there a Certificate of Fitness (C-92) holder on-site?',
                  ins.c92OnSite,
                ),
                pw.SizedBox(height: 8),
                _yesNoNAQuestion(
                  'For natural gas systems: Is there a dedicated gas cut-off valve installed?',
                  ins.gasCutoffValve,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // DEP Emissions & Registration
          PdfTemplate.sectionHeader('DEP Emissions & Registration'),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Generator size (kW): ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    PdfTemplate.inputField(ins.depSizeKw, width: 80),
                  ],
                ),
                pw.SizedBox(height: 12),
                _yesNoUnknownQuestion(
                  'Is the generator registered in the DEP Clean Air Tracking System (CATS)?',
                  ins.depRegisteredCats,
                ),
                pw.SizedBox(height: 8),
                _yesNoUnknownQuestion(
                  'Does the generator have a DEP Certificate to Operate?',
                  ins.depCertificateOperate,
                ),
                pw.SizedBox(height: 8),
                _yesNoUnknownQuestion(
                  'Is the generator Tier 4 compliant (EPA standard)?',
                  ins.tier4Compliant,
                ),
                pw.SizedBox(height: 8),
                _yesNoUnknownQuestion(
                  'If not Tier 4, has a smoke or stack test (EPA Method 9 or 5) been performed?',
                  ins.smokeOrStackTest,
                ),
                pw.SizedBox(height: 8),
                _yesNoQuestion(
                  'Are operational and maintenance records kept for at least 5 years?',
                  ins.recordsKept5Years,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Operational Use
          PdfTemplate.sectionHeader('Operational Use'),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _yesNoQuestion(
                  'Is the generator used only for emergency purposes?',
                  ins.emergencyOnly,
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Estimated annual runtime (hours): ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    PdfTemplate.inputField(
                      ins.estimatedAnnualRuntimeHours,
                      width: 50,
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                _yesNoNAQuestion(
                  'Is there on-site fuel sufficient for 6 hours of full-load operation?',
                  ins.fuelFor6hrs,
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  constraints: const pw.BoxConstraints(minHeight: 60),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    _notesPreview(ins.notes),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
    ],
    );
  }

  static const int _notesPreviewMaxChars = 450;
  static const int _notesPreviewMaxLines = 6;

  bool _notesOverflow(String notes) {
    final t = notes.trim();
    return t.length > _notesPreviewMaxChars ||
        '\n'.allMatches(t).length >= _notesPreviewMaxLines;
  }

  /// What fits in the page-2 notes box; the rest continues on the
  /// "Additional Notes" page (see [_notesOverflow]).
  String _notesPreview(String notes) {
    final t = notes.trim();
    if (!_notesOverflow(t)) return t;
    var preview = t.split('\n').take(_notesPreviewMaxLines).join('\n');
    if (preview.length > _notesPreviewMaxChars) {
      preview = preview.substring(0, _notesPreviewMaxChars);
    }
    return '${preview.trimRight()}…\n(continued on the Additional Notes page)';
  }

  /// Optional closing page: the result of the inspection at a glance.
  ///
  /// Counts what passed, then lists only what needs attention, so a reader can
  /// act on it without re-reading the five-page form.
  pw.Page _buildInspectionSummaryPage(Inspection ins) {
    final checks = <(String, bool, String)>[
      ('Genset runs under load', ins.gensetRunsUnderLoad, 'genset_runs_under_load'),
      ('Voltage and frequency OK', ins.voltageFrequencyOk, 'voltage_frequency_ok'),
      ('Exhaust OK', ins.exhaustOk, 'exhaust_ok'),
      ('Grounding and bonding OK', ins.groundingBondingOk, 'grounding_bonding_ok'),
      ('Control panel OK', ins.controlPanelOk, 'control_panel_ok'),
      ('Safety devices OK', ins.safetyDevicesOk, 'safety_devices_ok'),
      ('Deficiencies documented', ins.deficienciesDocumented, 'deficiencies_documented'),
      ('Load-bank test done', ins.loadbankDone, 'loadbank_done'),
      ('ATS verified', ins.atsVerified, 'ats_verified'),
    ];
    final failed = checks.where((c) => !c.$2).toList();

    final site = <(String, bool)>[
      ('Dedicated 2-hour room', ins.dedicatedRoom2hr),
      ('Separate from main service', ins.separateFromMainService),
      ('Area clear', ins.areaClear),
      ('Labels and E-stop visible', ins.labelsAndEStopVisible),
      ('Fire extinguisher present', ins.extinguisherPresent),
    ];
    final siteIssues = site.where((s) => !s.$2).map((s) => s.$1).toList();

    final regulatory = <(String, String)>[
      ('FDNY permit', ins.fdnyPermit),
      ('C-92 on site', ins.c92OnSite),
      ('DEP registered', ins.depRegisteredCats),
      ('DEP certificate to operate', ins.depCertificateOperate),
      ('Tier 4 compliant', ins.tier4Compliant),
      ('Smoke / stack test', ins.smokeOrStackTest),
    ];
    final regulatoryIssues =
        regulatory.where((r) => r.$2 == 'No' || r.$2 == 'Unknown').toList();

    final attention = failed.length +
        siteIssues.length +
        regulatoryIssues.length +
        (ins.fuelStoredOver1Yr ? 1 : 0);

    pw.Widget bullet(String text, {String? note}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  PdfTemplate.checkbox(false),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              ),
              if (note != null && note.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 16, top: 1),
                  child: pw.Text(note.trim(),
                      style: const pw.TextStyle(fontSize: 9)),
                ),
            ],
          ),
        );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfTemplate.pageFooter(
        context.pageNumber,
        total: context.pagesCount,
      ),
      build: (context) => [
        PdfTemplate.documentTitle('Inspection Summary'),
        PdfTemplate.labelValue('Site', ins.siteCode, bold: true),
        PdfTemplate.labelValue('Address', ins.address),
        PdfTemplate.labelValue('Service date', _formatDate(ins.serviceDate)),
        PdfTemplate.labelValue('Technician', ins.technicianName),
        PdfTemplate.labelValue(
          'Site grade',
          ins.siteGrade.isEmpty ? 'Not graded' : ins.siteGrade,
        ),
        pw.SizedBox(height: 10),
        PdfTemplate.sectionHeader(
          attention == 0
              ? 'Result: no items need attention'
              : 'Result: $attention item(s) need attention',
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Post-inspection checks passed: '
          '${checks.length - failed.length} of ${checks.length}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (failed.isNotEmpty) ...[
          pw.Text('Not passed', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          for (final c in failed) bullet(c.$1, note: ins.checklistNotes[c.$3]),
        ],
        if (siteIssues.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Site and safety', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          for (final s in siteIssues) bullet(s),
        ],
        if (regulatoryIssues.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Regulatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          for (final r in regulatoryIssues) bullet('${r.$1}: ${r.$2}'),
        ],
        if (ins.fuelStoredOver1Yr) ...[
          pw.SizedBox(height: 8),
          bullet('Fuel stored longer than one year (consider testing / conditioning)'),
        ],
        if (attention == 0) ...[
          pw.SizedBox(height: 4),
          pw.Text('Every recorded check passed.', style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 12),
        PdfTemplate.sectionHeader('Notes'),
        pw.SizedBox(height: 6),
        pw.Text(
          ins.notes.trim().isEmpty ? 'None recorded.' : ins.notes.trim(),
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  /// PAGE 3: Post-Inspection Checklist, Parts, Signatures
  pw.Page _buildPage3(Inspection ins) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfTemplate.pageFooter(
        context.pageNumber,
        total: context.pagesCount,
      ),
      build: (context) => [
          // Post-Inspection check list
          PdfTemplate.sectionHeader('Post-Inspection check list'),
          pw.SizedBox(height: 8),
          PdfTemplate.dataTable(
            headers: ['Inspection Item', 'Yes', 'No', 'Conclusions'],
            rows: [
              [
                'Verify generator starts and runs under load',
                PdfTemplate.checkbox(ins.gensetRunsUnderLoad),
                PdfTemplate.checkbox(!ins.gensetRunsUnderLoad),
                ins.checklistNotes['genset_runs_under_load'] ?? '',
              ],
              [
                'Check voltage and frequency output',
                PdfTemplate.checkbox(ins.voltageFrequencyOk),
                PdfTemplate.checkbox(!ins.voltageFrequencyOk),
                ins.checklistNotes['voltage_frequency_ok'] ?? '',
              ],
              [
                'Inspect exhaust system',
                PdfTemplate.checkbox(ins.exhaustOk),
                PdfTemplate.checkbox(!ins.exhaustOk),
                ins.checklistNotes['exhaust_ok'] ?? '',
              ],
              [
                'Verify grounding and bonding',
                PdfTemplate.checkbox(ins.groundingBondingOk),
                PdfTemplate.checkbox(!ins.groundingBondingOk),
                ins.checklistNotes['grounding_bonding_ok'] ?? '',
              ],
              [
                'Check control panel functionality',
                PdfTemplate.checkbox(ins.controlPanelOk),
                PdfTemplate.checkbox(!ins.controlPanelOk),
                ins.checklistNotes['control_panel_ok'] ?? '',
              ],
              [
                'Ensure all safety devices are operational',
                PdfTemplate.checkbox(ins.safetyDevicesOk),
                PdfTemplate.checkbox(!ins.safetyDevicesOk),
                ins.checklistNotes['safety_devices_ok'] ?? '',
              ],
              [
                'Document any deficiencies',
                PdfTemplate.checkbox(ins.deficienciesDocumented),
                PdfTemplate.checkbox(!ins.deficienciesDocumented),
                ins.checklistNotes['deficiencies_documented'] ?? '',
              ],
              [
                'Loadbank test performed (if applicable)',
                PdfTemplate.checkbox(ins.loadbankDone),
                PdfTemplate.checkbox(!ins.loadbankDone),
                ins.checklistNotes['loadbank_done'] ?? '',
              ],
              [
                'ATS functionality verified (if applicable)',
                PdfTemplate.checkbox(ins.atsVerified),
                PdfTemplate.checkbox(!ins.atsVerified),
                ins.checklistNotes['ats_verified'] ?? '',
              ],
              [
                'Has the fuel been stored over (1Yr)',
                PdfTemplate.checkbox(ins.fuelStoredOver1Yr),
                PdfTemplate.checkbox(!ins.fuelStoredOver1Yr),
                ins.checklistNotes['fuel_stored_over_1yr'] ?? '',
              ],
            ],
            columnWidths: [3, 0.4, 0.4, 2],
          ),
          pw.SizedBox(height: 16),

          // Parts and Materials Used
          PdfTemplate.sectionHeader('Parts and Materials Used'),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Date of last generator service: ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    PdfTemplate.inputField(ins.lastServiceDate, width: 100),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Has the generator undergone any of the following in the past year?',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 6),
                _serviceItem('Oil and filter change', ins.oilFilterChangeDate),
                _serviceItem('Fuel filter replacement', ins.fuelFilterDate),
                _serviceItem('Coolant flush', ins.coolantFlushDate),
                _serviceItem('Battery replacement', ins.batteryReplaceDate),
                _serviceItem('Air filter replacement', ins.airFilterDate),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplate.signatureBlock(
                label: 'Technician Signature',
                name: ins.technicianName,
                signaturePath: ins.technicianSignaturePath,
                date: _formatDate(ins.serviceDate),
              ),
              PdfTemplate.signatureBlock(
                label: 'Customer Signature',
                name: ins.customerName,
                signaturePath: ins.customerSignaturePath,
                date: _formatDate(ins.serviceDate),
              ),
            ],
          ),
    ],
    );
  }

  /// PAGE 4: Detailed Site Information & Fuel Monitoring
  pw.Page _buildPage4(Inspection ins) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfTemplate.pageFooter(
        context.pageNumber,
        total: context.pagesCount,
      ),
      build: (context) => [
          PdfTemplate.sectionHeader('Post-Inspection check list'),
          pw.SizedBox(height: 12),

          // Site details
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelValueRow('Site', ins.siteCode),
                    _labelValueRow('Technician', ins.technicianName),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelValueRow('Date', _formatDate(ins.serviceDate)),
                    _labelValueRow('Custodial Staff', ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _labelValueRow('TEMPERATURE', '', width: 60),
              pw.Text('°F', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 24),
              _labelValueRow('HUMIDITY', '', width: 60),
              pw.Text('%', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 12),

          // Locations
          pw.Row(
            children: [
              pw.Text(
                'Generator Location: ',
                style: const pw.TextStyle(fontSize: 9),
              ),
              PdfTemplate.locationCheckboxes(
                indoors: ins.locIndoors,
                outdoors: ins.locOutdoors,
                roof: ins.locRoof,
                basement: ins.locBasement,
                other: ins.locOther,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text('ATS Location: ', style: const pw.TextStyle(fontSize: 9)),
              PdfTemplate.checkboxWithLabel('Rooftop', false),
              pw.SizedBox(width: 8),
              PdfTemplate.checkboxWithLabel('Basement', false),
              pw.SizedBox(width: 8),
              PdfTemplate.checkboxWithLabel('Electrical Room', false),
              pw.SizedBox(width: 8),
              pw.Text('Other: _______', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 16),

          // Nameplate Data
          pw.Text(
            'Nameplate Data',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          _nameplateRow(
            'GENERATOR MFR.',
            ins.generatorMake,
            'MODEL NO.',
            ins.generatorModel,
            'SN',
            ins.generatorSerial,
          ),
          pw.SizedBox(height: 4),
          _nameplateRow(
            'KVA:',
            '',
            'KW:',
            ins.generatorKw,
            'VOLTS:',
            ins.voltageRating,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _labelValueRow('AMPS', '', width: 60),
              pw.SizedBox(width: 16),
              _labelValueRow('PHASE', '', width: 60),
              pw.SizedBox(width: 16),
              _labelValueRow('CYCLES', '', width: 60),
            ],
          ),
          pw.SizedBox(height: 4),
          _labelValueRow('RPM', '', width: 80),
          pw.SizedBox(height: 8),
          _nameplateRow(
            'GENERATOR CONTROL MFR.',
            '',
            'MODEL NO.',
            '',
            'S/N',
            '',
          ),
          pw.SizedBox(height: 4),
          _nameplateRow('GOVERNOR MFR.', '', 'MODEL NO.', '', 'S/N', ''),
          pw.SizedBox(height: 4),
          _nameplateRow('VOLTAGE REG.MFR.', '', 'MODEL NO.', '', 'S/N', ''),
          pw.SizedBox(height: 16),

          // Fuel Monitoring Data
          pw.Text(
            'Fuel Monitoring Data',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _labelValueRow('Volume', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('Ullage', '', width: 40),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('90% Ullage', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('TC Volume', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _labelValueRow('Height', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('Water', '', width: 40),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('Water', '', width: 50),
              pw.Text('Inches', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 12),
              _labelValueRow('Temp °F', '', width: 50),
            ],
          ),
          pw.SizedBox(height: 8),
          _labelValueRow('Time', '', width: 100),
          pw.SizedBox(height: 16),

          // Comments and Deficiencies
          pw.Container(
            width: double.infinity,
            height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey600),
                    ),
                  ),
                  child: pw.Text(
                    'Comments:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(child: pw.SizedBox()),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey600),
                    ),
                  ),
                  child: pw.Text(
                    'Deficiencies:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(child: pw.SizedBox()),
              ],
            ),
          ),
    ],
    );
  }

  /// PAGE 5: Load Test Table
  pw.Page _buildPage5(Inspection ins) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'EQPT. INVENTORY NO. ',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      PdfTemplate.inputField('', width: 120),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'TESTED BY: ',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      PdfTemplate.inputField(ins.technicianName, width: 120),
                    ],
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Rows are stretched so the grid fills at least three quarters
          // of the landscape page, leaving room to write readings by hand.
          PdfTemplate.loadTestTable(
            readings: [],
            fillHeight: PdfPageFormat.letter.landscape.height * 0.75,
          ),
          pw.Spacer(),
          PdfTemplate.pageFooter(context.pageNumber),
        ],
      ),
    );
  }

  // ---------- Helper widgets & utilities ----------

  pw.Widget _yesNoQuestion(String question, bool value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(question, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(width: 8),
        PdfTemplate.checkboxWithLabel('Yes', value),
        pw.SizedBox(width: 8),
        PdfTemplate.checkboxWithLabel('No', !value),
      ],
    );
  }

  pw.Widget _yesNoUnknownQuestion(String question, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(question, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(width: 8),
        PdfTemplate.yesNoSelector(value),
      ],
    );
  }

  pw.Widget _yesNoNAQuestion(String question, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(question, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(width: 8),
        PdfTemplate.yesNoSelector(value),
      ],
    );
  }

  pw.Widget _serviceItem(String label, String date) {
    final hasDate = date.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text('- ', style: const pw.TextStyle(fontSize: 9)),
          PdfTemplate.checkbox(hasDate),
          pw.SizedBox(width: 4),
          pw.Text('$label;', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 8),
          pw.Text('If Yes: Date: ', style: const pw.TextStyle(fontSize: 9)),
          PdfTemplate.inputField(date, width: 80),
        ],
      ),
    );
  }

  pw.Widget _labelValueRow(String label, String value, {double width = 100}) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9)),
        PdfTemplate.inputField(value, width: width),
      ],
    );
  }

  pw.Widget _nameplateRow(
    String label1,
    String value1,
    String label2,
    String value2,
    String label3,
    String value3,
  ) {
    return pw.Row(
      children: [
        pw.Text('$label1 ', style: const pw.TextStyle(fontSize: 9)),
        PdfTemplate.inputField(value1, width: 80),
        pw.SizedBox(width: 12),
        pw.Text('$label2 ', style: const pw.TextStyle(fontSize: 9)),
        PdfTemplate.inputField(value2, width: 80),
        pw.SizedBox(width: 12),
        pw.Text('$label3 ', style: const pw.TextStyle(fontSize: 8)),
        PdfTemplate.inputField(value3, width: 80),
      ],
    );
  }

  String _formatDate(DateTime date) => date.toIso8601String().split('T').first;

  pw.Widget _nameplateSummaryTable(NameplateData m) {
    final rows = <List<String>>[
      ['Generator Mfr.', m.generatorMfr],
      ['Model', m.generatorModel],
      ['Serial', m.generatorSn],
      ['KVA', m.kva],
      ['KW', m.kw],
      ['Volts', m.volts],
      ['Amps', m.amps],
      ['Phase', m.phase],
      ['Cycles', m.cycles],
      ['RPM', m.rpm],
      ['Control Mfr.', m.controlMfr],
      ['Control Model', m.controlModel],
      ['Control SN', m.controlSn],
      ['Governor Mfr.', m.governorMfr],
      ['Governor Model', m.governorModel],
      ['Governor SN', m.governorSn],
      ['Regulator Mfr.', m.regulatorMfr],
      ['Regulator Model', m.regulatorModel],
      ['Regulator SN', m.regulatorSn],
      ['Fuel Vol (gal)', m.volumeGal],
      ['Ullage (gal)', m.ullageGal],
      ['90% Ullage (gal)', m.ullage90Gal],
      ['TC Vol (gal)', m.tcVolumeGal],
      ['Height (gal)', m.heightGal],
      ['Water (gal)', m.waterGal],
      ['Water (in)', m.waterInches],
      ['Temp (°F)', m.tempF],
      ['Time', m.time],
      ['Comments', m.comments],
      ['Deficiencies', m.deficiencies],
    ];

    final left = <List<String>>[];
    final right = <List<String>>[];
    for (var i = 0; i < rows.length; i++) {
      (i % 2 == 0 ? left : right).add(rows[i]);
    }

    pw.Widget kv(List<List<String>> kv) => pw.TableHelper.fromTextArray(
      headers: const ['Field', 'Value'],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      data: kv,
      border: null,
      cellAlignment: pw.Alignment.centerLeft,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: kv(left)),
        pw.SizedBox(width: 12),
        pw.Expanded(child: kv(right)),
      ],
    );
  }

  pw.Widget _intervalsTable(List<TestIntervalRecord> rows) {
    final headers = [
      '#',
      'Target kW',
      'RPM',
      'Hz',
      'Eng. Water °F',
      'Rad. Water °F',
      'Oil Temp °F',
      'Oil PSI',
      'Panel V',
      'Measured V',
      'Panel A',
      'Measured A',
      'Panel kW',
      'Measured kW',
      'Battery V',
      'Fuel PSI',
    ];
    final data = <List<String>>[
      for (final r in rows)
        [
          '${r.index + 1}',
          r.realtimeKwTarget,
          r.engineRpm,
          r.frequencyHz,
          r.engineWaterF,
          r.radiatorWaterF,
          r.engineOilTempF,
          r.engineOilPsi,
          r.panelVolt,
          r.measuredVolt,
          r.panelAmp,
          r.measuredAmp,
          r.panelKw,
          r.measuredKw,
          r.batteryVolt,
          r.fuelPressure,
        ],
    ];
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      border: null,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _buildLoadTestTable(List<LoadTestRecord> rows) {
    final headers = <String>[
      '#',
      '% Load',
      'Minutes',
      'V L1-L2',
      'V L2-L3',
      'V L1-L3',
      'Hz',
      'Current (A)',
      'Measured kW',
      'Pass',
      'Notes',
    ];

    final data = <List<String>>[
      for (final r in rows)
        [
          '${r.stepIndex + 1}',
          '${r.loadPercent}',
          '${r.durationMinutes}',
          r.voltageL1L2,
          r.voltageL2L3,
          r.voltageL1L3,
          r.frequencyHz,
          r.currentA,
          r.measuredKw,
          r.pass ? 'Yes' : 'No',
          r.notes,
        ],
    ];

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.6),
      1: const pw.FlexColumnWidth(0.9),
      2: const pw.FlexColumnWidth(1.0),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.2),
      5: const pw.FlexColumnWidth(1.2),
      6: const pw.FlexColumnWidth(0.9),
      7: const pw.FlexColumnWidth(1.2),
      8: const pw.FlexColumnWidth(1.2),
      9: const pw.FlexColumnWidth(0.9),
      10: const pw.FlexColumnWidth(2.5),
    };

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: const {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        6: pw.Alignment.center,
        9: pw.Alignment.center,
      },
      columnWidths: colWidths,
    );
  }

  // -------- Maintenance helpers --------

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  pw.Widget _maintLabelValueRow(
    String label,
    String value, {
    bool wrap = false,
    double labelWidth = 120,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: labelWidth,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
            softWrap: wrap,
          ),
        ),
      ],
    );
  }

  /// The drawn signature for [type] ('technician' | 'customer') as an image,
  /// or null when none was captured.
  ///
  /// Tries, in order: bytes still in memory from this session, the stored path
  /// on the record (web store or filesystem, re-anchored if the app folder
  /// moved), then the canonical per-record signature file.
  Future<pw.MemoryImage?> _loadMaintenanceSignature(
    MaintenanceRecord m,
    String type,
  ) async {
    try {
      final isTech = type == 'technician';
      Uint8List? bytes =
          isTech ? m.technicianSignatureBytes : m.customerSignatureBytes;

      final path = isTech ? m.technicianSignaturePath : m.customerSignaturePath;
      if ((bytes == null || bytes.isEmpty) && path != null && path.isNotEmpty) {
        bytes = WebFileStore.instance.getSync(path);
        if (bytes == null && !kIsWeb) {
          final file = await PathResolver.resolveFile(path);
          bytes = await file?.readAsBytes();
        }
      }

      if ((bytes == null || bytes.isEmpty) && !kIsWeb) {
        final file =
            await FileStorageService.instance.getMaintenanceSignature(m.id, type);
        bytes = await file?.readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('[PdfService] Could not load $type signature: $e');
      return null;
    }
  }

  /// One signature box: the drawn image sitting on the signature line.
  // ---------- Storage + email/share helper ----------

  Future<PdfExportResult> _saveAndMaybeEmailPdf({
    required List<int> bytes,
    required String fileName,
    required PdfExportPrefs prefs,
  }) async {
    String? savePath;

    if (kIsWeb) {
      // Browser builds have no writable filesystem path. Persist the document
      // in IndexedDB under a logical path so the inspection detail page can
      // recognize and preview it just like native builds do.
      final logicalPath = 'pdfs/${fileName.replaceAll(r'\', '/')}';
      await WebFileStore.instance.put(logicalPath, Uint8List.fromList(bytes));

      try {
        await SyncService.instance.enqueueBytesUpload(
          storePath: logicalPath,
          remotePath: logicalPath,
          contentType: 'application/pdf',
        );
      } catch (e) {
        debugPrint('[PdfService] Could not queue web PDF backup: $e');
      }

      return PdfExportResult(filePath: logicalPath, emailed: false);
    }

    // MOBILE / DESKTOP
    io.Directory baseDir;

    if (prefs.customDirectoryPath != null) {
      baseDir = io.Directory(prefs.customDirectoryPath!);
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
    } else {
      // Use the app's managed PDF directory:
      // dev (desktop): <project>/dev_data/pdfs/, production: on-device app data.
      baseDir = await FileStorageService.instance.getPdfsDirectory();
    }

    final appDir = io.Directory(p.join(baseDir.path, prefs.appSubfolder));
    if (!appDir.existsSync()) {
      appDir.createSync(recursive: true);
    }

    final fullPath = p.join(appDir.path, fileName);
    final file = io.File(fullPath);

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    await file.writeAsBytes(bytes, flush: true);
    savePath = file.path;

    debugPrint('PDF saved to: $savePath');

    // Queue the generated PDF for cloud backup. [fileName] is relative to the
    // PDFs root (e.g. "inspections/<site>/inspection_x.pdf"), so mirror it under
    // a "pdfs/" prefix in storage. Never let a backup hiccup break PDF export.
    try {
      final remotePath = 'pdfs/${fileName.replaceAll(r'\', '/')}';
      await SyncService.instance.enqueueFileUpload(
        localPath: savePath,
        remotePath: remotePath,
        contentType: 'application/pdf',
      );
    } catch (e) {
      debugPrint('[PdfService] Could not queue PDF backup: $e');
    }

    // Only attempt email/share if the user has given permission
    if (!prefs.emailAllowed) {
      return PdfExportResult(filePath: savePath, emailed: false);
    }

    // Trigger default share / email if possible
    final xFile = XFile(
      savePath,
      mimeType: 'application/pdf',
      name: p.basename(savePath),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: 'Generator Service Report',
        text: prefs.defaultRecipient != null
            ? 'Please see attached generator report for your records.'
            : 'Please see attached generator report.',
      ),
    );

    return PdfExportResult(filePath: savePath, emailed: true);
  }

  /// Optionally copy signature image files into the same folder as the PDF.
  ///
  /// Adjust field names below to match your [MaintenanceRecord] model.
  Future<void> _copySignaturesIfAny({
    required MaintenanceRecord? maintenance,
    required String folderPath,
  }) async {
    if (maintenance == null) return;

    // Example field names – update to your actual model fields if needed.
    final techSigPath = maintenance.technicianSignaturePath;
    final customerSigPath = maintenance.customerSignaturePath;

    if (techSigPath != null && io.File(techSigPath).existsSync()) {
      final dest = p.join(folderPath, 'tech_signature_${maintenance.id}.png');
      await io.File(techSigPath).copy(dest);
    }

    if (customerSigPath != null && io.File(customerSigPath).existsSync()) {
      final dest = p.join(
        folderPath,
        'customer_signature_${maintenance.id}.png',
      );
      await io.File(customerSigPath).copy(dest);
    }
  }

  // Save inspection signature
  Future<void> saveSignature(
    String inspectionId,
    Uint8List signatureBytes,
  ) async {
    final path = await FileStorageService.instance.saveInspectionSignature(
      inspectionId: inspectionId,
      signatureBytes: signatureBytes,
    );

    debugPrint('Signature saved: $path');
  }

  // Load signature
  Future<Uint8List?> loadSignature(String inspectionId) async {
    final file = await FileStorageService.instance.getInspectionSignature(
      inspectionId,
    );

    if (file != null) {
      return await file.readAsBytes();
    }

    return null;
  }

  // Save inspection PDF
  Future<String> saveInspectionPdf({
    required String inspectionId,
    required Uint8List pdfBytes,
  }) async {
    // Use FileStorageService instead of manual path
    return await FileStorageService.instance.saveInspectionPdf(
      inspectionId: inspectionId,
      pdfBytes: pdfBytes,
    );
  }

  // Save maintenance PDF
  Future<String> saveMaintenancePdf({
    required String jobId,
    required Uint8List pdfBytes,
  }) async {
    return await FileStorageService.instance.saveMaintenancePdf(
      jobId: jobId,
      pdfBytes: pdfBytes,
    );
  }


  // ---------- Vehicle report ----------

  /// Build the vehicle report: facts, driver, inspections (with every flagged
  /// item), maintenance history, tools, then photo appendices.
  Future<Uint8List> buildVehiclePdfBytes(VehicleReportData data) async {
    final v = data.vehicle;
    final pdf = pw.Document();

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        );

    final facts = <(String, String)>[
      ('Designation', v.designation.trim().isEmpty ? v.displayTitle : v.designation),
      ('Type', v.vehicleType.label),
      if (v.makeModel.isNotEmpty) ('Make / Model', v.makeModel),
      if (v.modelYear != null) ('Year', '${v.modelYear}'),
      ('VIN', v.vin ?? 'Not recorded'),
      ('License plate',
          v.licensePlate.trim().isEmpty ? 'Not recorded' : v.licensePlate.trim()),
      ('Odometer', '${v.odometer} mi'),
      ('Status', v.status.label),
      ('Assigned driver', data.driverName ?? 'Unassigned'),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(
            'Vehicle Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'A&S Electric – Generated ${_fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Divider(),
          for (final (label, value) in facts)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: _maintLabelValueRow(label, value, wrap: true),
            ),
          if (v.notes.trim().isNotEmpty) ...[
            heading('Notes'),
            pw.Text(v.notes.trim(), style: const pw.TextStyle(fontSize: 9)),
          ],

          heading('Inspections'),
          if (data.inspections.isEmpty)
            pw.Text('No inspections recorded.',
                style: const pw.TextStyle(fontSize: 9))
          else ...[
            PdfTemplate.dataTable(
              headers: ['Date', 'Type', 'Inspector', 'Odometer', 'Flagged'],
              rows: [
                for (final i in data.inspections.take(12))
                  [
                    _fmtDate(i.inspectedAt),
                    i.cadence.label,
                    i.inspectorName,
                    i.odometer > 0 ? '${i.odometer} mi' : '',
                    i.hasIssues ? '${i.issueCount}' : 'None',
                  ],
              ],
            ),
            // Spell out every flagged item on the most recent inspections so
            // the PDF says what was wrong, not just that something was.
            for (final i in data.inspections.take(3))
              if (i.hasIssues) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  '${i.cadence.label} inspection ${_fmtDate(i.inspectedAt)} – flagged items',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                for (final item in inspectionItemsFor(i.cadence))
                  if ((i.results[item.key]?.needsFollowUp) ?? false)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Text(
                        '• ${item.label}: ${i.results[item.key]!.label}'
                        '${(i.itemNotes[item.key] ?? '').isEmpty ? '' : ' – ${i.itemNotes[item.key]}'}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                if (i.notes.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8, top: 2),
                    child: pw.Text('Notes: ${i.notes}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
              ],
          ],

          heading('Maintenance history'),
          if (data.checks.isEmpty)
            pw.Text('No maintenance checks recorded.',
                style: const pw.TextStyle(fontSize: 9))
          else
            PdfTemplate.dataTable(
              headers: ['Date', 'Odometer', 'Brakes', 'Battery', 'Notes'],
              rows: [
                for (final c in data.checks.take(12))
                  [
                    _fmtDate(c.checkedAt.toLocal()),
                    '${c.odometer} mi',
                    c.brakeStatus.label,
                    c.batteryStatus.label,
                    c.notes,
                  ],
              ],
            ),

          heading('Tools and equipment'),
          if (data.assets.isEmpty)
            pw.Text('No tools assigned.', style: const pw.TextStyle(fontSize: 9))
          else
            PdfTemplate.dataTable(
              headers: ['Tool', 'Serial', 'Status', 'Notes'],
              rows: [
                for (final a in data.assets)
                  [a.label, a.serial, a.status, a.notes],
              ],
            ),
        ],
      ),
    );

    // Photos taken on the vehicle itself, then those from the latest inspection.
    await _addPhotosAppendix(pdf, PhotoAttachment.ownerVehicle, v.id);
    if (data.inspections.isNotEmpty) {
      await _addPhotosAppendix(
        pdf,
        PhotoAttachment.ownerVehicleInspection,
        data.inspections.first.id,
      );
    }

    return pdf.save();
  }

  /// Generate the vehicle report and store it in the PDF library.
  Future<PdfExportResult> generateVehiclePdf(
    VehicleReportData data, {
    PdfExportPrefs? prefs,
  }) async {
    final bytes = await buildVehiclePdfBytes(data);
    final name = data.vehicle.displayTitle
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final shortId =
        data.vehicle.id.length > 8 ? data.vehicle.id.substring(0, 8) : data.vehicle.id;
    final fileName = p.join(
      'vehicles',
      'Vehicle_${name}_${_fmtDate(DateTime.now())}_$shortId.pdf',
    );
    return _saveAndMaybeEmailPdf(
      bytes: bytes,
      fileName: fileName,
      prefs: prefs ?? const PdfExportPrefs(emailAllowed: false),
    );
  }

  // Get PDF for sharing
  Future<File?> getInspectionPdf(String inspectionId) async {
    return await FileStorageService.instance.getInspectionPdf(inspectionId);
  }
}

/// A decoded photo ready to render in the PDF photo appendix.
class _PdfPhoto {
  _PdfPhoto(this.image, this.caption);

  final pw.MemoryImage image;
  final String caption;
}
