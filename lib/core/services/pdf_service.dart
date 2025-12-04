import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
import '../../modules/inspections/infra/models/inspection.dart';
import '../../modules/inspections/infra/models/nameplate_data.dart';
import '../../modules/load_test/infra/models/load_test_record.dart';
import '../../modules/load_test/infra/models/test_interval_record.dart';
import '../../modules/maintenance/infra/models/maintenance_record.dart';
import '../../shared/presenter/layout/pdf/pdf_template.dart';
import '../storage/hive/hive_boxes.dart';

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

  const PdfExportResult({
    this.filePath,
    this.emailed = false,
  });
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

    debugPrint('Inspection PDF saved to: ${result.filePath ?? '(no local path)'}');
    return result.filePath ?? '';
  }

  /// Build the inspection PDF as raw bytes.
  ///
  /// Used internally by [generatePdfForInspection], but you can also call it
  /// directly if you need to do custom storage controllers.
  Future<Uint8List> _buildInspectionPdfBytes(Inspection ins) async {
    // Load fonts
    final baseFont = await rootBundle.load('assets/fonts/NotoSans/NotoSans-Regular.ttf');
    final boldFont = await rootBundle.load('assets/fonts/NotoSans/NotoSans-Bold.ttf');

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
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _nameplateSummaryTable(nameplate),
          ],
        ),
      );
    }

    // TEST READING INTERVALS (tabular across pages)
    final intervals = HiveBoxes.testIntervals.values
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
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _intervalsTable(intervals),
          ],
        ),
      );
    }

    // LOAD TEST RESULTS
    final loadRows = HiveBoxes.loadTests.values
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
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildLoadTestTable(loadRows),
          ],
        ),
      );
    }

    return pdf.save();
  }

  /// Build the maintenance PDF and return bytes (for saving/emailing/etc.)
  Future<Uint8List> buildMaintenancePdfBytes(MaintenanceRecord m) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          _buildMaintenanceHeader(),
          pw.SizedBox(height: 8),
          _buildMaintenanceSiteInfo(m),
          pw.SizedBox(height: 12),
          _buildMaintenanceWalkthrough(m),
          pw.SizedBox(height: 12),
          _buildMaintenanceGeneral(m),
          pw.SizedBox(height: 12),
          _buildMaintenanceActions(m),
          pw.SizedBox(height: 12),
          _buildMaintenancePostService(m),
          pw.SizedBox(height: 12),
          _buildMaintenanceParts(m),
          pw.SizedBox(height: 12),
          _buildMaintenanceSignatures(m),
        ],
      ),
    );

    return pdf.save();
  }

  /// Backward-compatible wrapper you can call from `MaintenanceRepo.exportPdf(rec)`.
  ///
  /// - Saves the PDF under an app folder.
  /// - Optionally opens share/email sheet if [prefs.emailAllowed] is true.
  /// - Copies signature images (if you wire those fields in the model).
  Future<void> generateMaintenancePdf(
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
      await _copySignaturesIfAny(
        maintenance: m,
        folderPath: folder,
      );
    }
  }

  String _buildMaintenanceFileName(MaintenanceRecord m) {
    final site =
    (m.siteCode.isNotEmpty ? m.siteCode : 'maintenance').replaceAll(' ', '_');
    final date = _fmtDate(m.dateOfService ?? m.createdAt);
    return 'Maintenance_${site}_$date.pdf';
  }

  /// PAGE 1: Site and Generator Information, Location & Safety
  pw.Page _buildPage1(Inspection ins, pw.MemoryImage? logo) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                PdfTemplate.checkboxWithLabel('Green', ins.siteGrade == 'Green'),
                pw.SizedBox(width: 12),
                PdfTemplate.checkboxWithLabel('Amber', ins.siteGrade == 'Amber'),
                pw.SizedBox(width: 12),
                PdfTemplate.checkboxWithLabel('Red', ins.siteGrade == 'Red'),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          PdfTemplate.formFieldsTable({
            'Site Code': ins.siteCode,
            'Address': ins.address,
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
          pw.Spacer(),
          PdfTemplate.pageFooter(1),
        ],
      ),
    );
  }

  /// PAGE 2: Fuel Storage, DEP, Operational Use
  pw.Page _buildPage2(Inspection ins) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                    pw.Text(
                      'gallons',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
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
                  height: 60,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    ins.notes,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          pw.Spacer(),
          PdfTemplate.pageFooter(2),
        ],
      ),
    );
  }

  /// PAGE 3: Post-Inspection Checklist, Parts, Signatures
  pw.Page _buildPage3(Inspection ins) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                '',
              ],
              [
                'Check voltage and frequency output',
                PdfTemplate.checkbox(ins.voltageFrequencyOk),
                PdfTemplate.checkbox(!ins.voltageFrequencyOk),
                '',
              ],
              [
                'Inspect exhaust system',
                PdfTemplate.checkbox(ins.exhaustOk),
                PdfTemplate.checkbox(!ins.exhaustOk),
                '',
              ],
              [
                'Verify grounding and bonding',
                PdfTemplate.checkbox(ins.groundingBondingOk),
                PdfTemplate.checkbox(!ins.groundingBondingOk),
                '',
              ],
              [
                'Check control panel functionality',
                PdfTemplate.checkbox(ins.controlPanelOk),
                PdfTemplate.checkbox(!ins.controlPanelOk),
                '',
              ],
              [
                'Ensure all safety devices are operational',
                PdfTemplate.checkbox(ins.safetyDevicesOk),
                PdfTemplate.checkbox(!ins.safetyDevicesOk),
                '',
              ],
              [
                'Document any deficiencies',
                PdfTemplate.checkbox(ins.deficienciesDocumented),
                PdfTemplate.checkbox(!ins.deficienciesDocumented),
                '',
              ],
              [
                'Loadbank test performed (if applicable)',
                PdfTemplate.checkbox(ins.loadbankDone),
                PdfTemplate.checkbox(!ins.loadbankDone),
                '',
              ],
              [
                'ATS functionality verified (if applicable)',
                PdfTemplate.checkbox(ins.atsVerified),
                PdfTemplate.checkbox(!ins.atsVerified),
                '',
              ],
              [
                'Has the fuel been stored over (1Yr)',
                PdfTemplate.checkbox(ins.fuelStoredOver1Yr),
                PdfTemplate.checkbox(!ins.fuelStoredOver1Yr),
                '',
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
          pw.Spacer(),
          PdfTemplate.pageFooter(3),
        ],
      ),
    );
  }

  /// PAGE 4: Detailed Site Information & Fuel Monitoring
  pw.Page _buildPage4(Inspection ins) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
              pw.Text(
                'ATS Location: ',
                style: const pw.TextStyle(fontSize: 9),
              ),
              PdfTemplate.checkboxWithLabel('Rooftop', false),
              pw.SizedBox(width: 8),
              PdfTemplate.checkboxWithLabel('Basement', false),
              pw.SizedBox(width: 8),
              PdfTemplate.checkboxWithLabel('Electrical Room', false),
              pw.SizedBox(width: 8),
              pw.Text(
                'Other: _______',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Nameplate Data
          pw.Text(
            'Nameplate Data',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
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
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _labelValueRow('Volume', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 12),
              _labelValueRow('Ullage', '', width: 40),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 12),
              _labelValueRow('90% Ullage', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 12),
              _labelValueRow('TC Volume', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _labelValueRow('Height', '', width: 50),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 12),
              _labelValueRow('Water', '', width: 40),
              pw.Text('GAL', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 12),
              _labelValueRow('Water', '', width: 50),
              pw.Text('Inches', style: const pw.TextStyle(fontSize: 8)),
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
          pw.Spacer(),
          PdfTemplate.pageFooter(4),
        ],
      ),
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
                      pw.Text('EQPT. INVENTORY NO. ',
                          style: const pw.TextStyle(fontSize: 9)),
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
                      pw.Text('TESTED BY: ',
                          style: const pw.TextStyle(fontSize: 9)),
                      PdfTemplate.inputField(
                        ins.technicianName,
                        width: 120,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          PdfTemplate.loadTestTable(readings: []),
          pw.Spacer(),
          PdfTemplate.pageFooter(5),
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

  pw.Widget _labelValueRow(
      String label,
      String value, {
        double width = 100,
      }) {
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
        pw.Text('$label1 ', style: const pw.TextStyle(fontSize: 8)),
        PdfTemplate.inputField(value1, width: 80),
        pw.SizedBox(width: 12),
        pw.Text('$label2 ', style: const pw.TextStyle(fontSize: 8)),
        PdfTemplate.inputField(value2, width: 80),
        pw.SizedBox(width: 12),
        pw.Text('$label3 ', style: const pw.TextStyle(fontSize: 8)),
        PdfTemplate.inputField(value3, width: 80),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      date.toIso8601String().split('T').first;

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

    pw.Widget kv(List<List<String>> kv) =>
        pw.TableHelper.fromTextArray(
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

  pw.Widget _buildMaintenanceHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Generator Maintenance & Repair Checklist',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'A&S Electric – Generator Service Division',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _yesNo(bool value) => value ? 'Yes' : 'No';

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
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
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

  pw.Widget _bulletRow(String label, bool value) {
    return pw.Row(
      children: [
        pw.Text(
          value ? '• ' : '○ ',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Expanded(
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMaintenanceSiteInfo(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Site & Generator Information',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        _maintLabelValueRow('Site Code:', m.siteCode),
        _maintLabelValueRow('Address:', m.address, wrap: true),
        _maintLabelValueRow(
          'Date of Service:',
          m.dateOfService != null ? _fmtDate(m.dateOfService!) : '',
        ),
        _maintLabelValueRow('Technician:', m.technicianName),
        _maintLabelValueRow('Generator Make:', m.generatorMake),
        _maintLabelValueRow('Generator Model:', m.generatorModel),
        _maintLabelValueRow('Serial #:', m.generatorSerial),
        _maintLabelValueRow('Generator kW:', m.generatorKw),
        _maintLabelValueRow('Engine Hours:', m.engineHours),
        _maintLabelValueRow('Fuel Type:', m.fuelType),
        _maintLabelValueRow('Last Fuel Delivery:', m.lastFuelDeliveryDate),
        _maintLabelValueRow('Voltage Rating:', m.voltageRating),
      ],
    );
  }

  pw.Widget _buildMaintenanceWalkthrough(MaintenanceRecord m) {
    final loc = m.generatorLocation;
    final locOther = m.generatorLocationOther;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Initial Walkthrough & Location',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        _maintLabelValueRow(
          'Generator Location:',
          loc == 'Other' && locOther.isNotEmpty ? '$loc ($locOther)' : loc,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Enclosure Condition:',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 2),
        _bulletRow('Enclosure intact', m.enclosureIntact),
        _bulletRow('Enclosure damaged', m.enclosureDamaged),
        _bulletRow('No enclosure', m.noEnclosure),
        pw.SizedBox(height: 4),
        pw.Text(
          'Safety & Hazards:',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 2),
        _bulletRow('Visible damage or leaks', m.visibleDamageOrLeaks),
        _bulletRow(
          'Area clear of debris / tripping hazards',
          m.areaClearOfHazards,
        ),
        _bulletRow(
          'Warning / safety labels visible',
          m.warningLabelsVisible,
        ),
        _bulletRow(
          'Fire extinguisher present & accessible',
          m.fireExtinguisherPresent,
        ),
      ],
    );
  }

  pw.Widget _buildMaintenanceGeneral(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'General Maintenance',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Battery',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _maintLabelValueRow(
          'Needs replacement:',
          _yesNo(m.batteryNeedsReplace),
        ),
        _maintLabelValueRow(
          'Recently replaced:',
          _yesNo(m.batteryRecentlyReplaced),
        ),
        _maintLabelValueRow('Mfg. Date:', m.batteryMfgDate),
        _maintLabelValueRow('Part No.:', m.batteryPartNo),
        _maintLabelValueRow('Type:', m.batteryType),
        pw.SizedBox(height: 4),
        pw.Text(
          'Air Filter',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _maintLabelValueRow(
          'Needs replacement:',
          _yesNo(m.airFilterNeedsReplace),
        ),
        _maintLabelValueRow(
          'Recently replaced:',
          _yesNo(m.airFilterRecentlyReplaced),
        ),
        _maintLabelValueRow(
          'Last replaced:',
          m.airFilterLastReplacedDate,
        ),
        _maintLabelValueRow('Part No.:', m.airFilterPartNo),
        pw.SizedBox(height: 4),
        pw.Text(
          'Coolant',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _maintLabelValueRow('Level:', m.coolantLevel),
        _maintLabelValueRow('Color:', m.coolantColor),
        pw.SizedBox(height: 4),
        pw.Text(
          'Hoses',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _buildHoseRow(
          'Coolant hoses',
          compromised: m.coolantHosesCompromised,
          recommendChange: m.coolantHosesRecommendChange,
          notes: m.coolantHosesInfo,
        ),
        _buildHoseRow(
          'Fuel hoses',
          compromised: m.fuelHosesCompromised,
          recommendChange: m.fuelHosesRecommendChange,
          notes: m.fuelHosesInfo,
        ),
        _buildHoseRow(
          'Air intake hoses',
          compromised: m.airIntakeHosesCompromised,
          recommendChange: m.airIntakeHosesRecommendChange,
          notes: m.airIntakeHosesInfo,
        ),
        _buildHoseRow(
          'Oil hoses',
          compromised: m.oilHosesCompromised,
          recommendChange: m.oilHosesRecommendChange,
          notes: m.oilHosesInfo,
        ),
        _buildHoseRow(
          'Additional hoses',
          compromised: m.additionalHosesCompromised,
          recommendChange: m.additionalHosesRecommendChange,
          notes: m.additionalHosesInfo,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Cannisters / Filters Needed',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _buildCanRow('Lube filter', m.canLube, m.canLubePartNo),
        _buildCanRow('Fuel filter', m.canFuel, m.canFuelPartNo),
        _buildCanRow('Water separator', m.canWaterSep, m.canWaterSepPartNo),
        _buildCanRow('Oil filter', m.canOil, m.canOilPartNo),
        _buildCanRow(
          m.canOther1Label.isEmpty ? 'Other 1' : m.canOther1Label,
          m.canOther1,
          m.canOther1PartNo,
        ),
        _buildCanRow(
          m.canOther2Label.isEmpty ? 'Other 2' : m.canOther2Label,
          m.canOther2,
          m.canOther2PartNo,
        ),
      ],
    );
  }

  pw.Widget _buildHoseRow(
      String label, {
        required bool compromised,
        required bool recommendChange,
        required String notes,
      }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9),
        ),
        _maintLabelValueRow(
          'Compromised:',
          _yesNo(compromised),
          labelWidth: 80,
        ),
        _maintLabelValueRow(
          'Recommend change:',
          _yesNo(recommendChange),
          labelWidth: 80,
        ),
        if (notes.isNotEmpty)
          _maintLabelValueRow(
            'Notes:',
            notes,
            labelWidth: 80,
            wrap: true,
          ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  pw.Widget _buildCanRow(String label, bool checked, String partNo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          checked ? '[x]' : '[ ]',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          'Part No: $partNo',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _buildMaintenanceActions(MaintenanceRecord m) {
    pw.Widget action(String label, bool value, String notes) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                value ? '[x] ' : '[ ] ',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Expanded(
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
              child: pw.Text(
                'Notes: $notes',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Maintenance Actions Performed',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        action('Oil filter changed', m.oilFilterChanged, m.oilFilterNotes),
        action(
          'Fuel filter replaced',
          m.fuelFilterReplaced,
          m.fuelFilterNotes,
        ),
        action(
          'Coolant flushed / topped off',
          m.coolantFlushed,
          m.coolantNotes,
        ),
        action(
          'Battery replaced / serviced',
          m.batteryReplaced,
          m.batteryNotes,
        ),
        action(
          'Air filter replaced',
          m.airFilterReplaced,
          m.airFilterNotes,
        ),
        action(
          'Belts / hoses replaced',
          m.beltsHosesReplaced,
          m.beltsHosesNotes,
        ),
        action(
          'Block heater tested & functional',
          m.blockHeaterTested,
          m.blockHeaterNotes,
        ),
        action(
          'Racor / fuel-water separator serviced',
          m.racorServiced,
          m.racorNotes,
        ),
        action(
          'ATS / controller inspected',
          m.atsControllerInspected,
          m.atsControllerNotes,
        ),
        action(
          'CDVR programmed / calibrated',
          m.cdvrProgrammed,
          m.cdvrNotes,
        ),
        action(
          'Under-voltage issue repaired',
          m.undervoltageRepaired,
          m.undervoltageNotes,
        ),
        action(
          'Hazardous material removed / disposed',
          m.hazmatRemoved,
          m.hazmatNotes,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Service Observations / Notes:',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        if (m.serviceObservations.isNotEmpty)
          pw.Text(
            m.serviceObservations,
            style: const pw.TextStyle(fontSize: 9),
          ),
      ],
    );
  }

  pw.Widget _buildMaintenancePostService(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Post-Service Checklist',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        _bulletRow(
          'Verified generator runs under load',
          m.postVerifyRunsUnderLoad,
        ),
        _bulletRow(
          'Checked voltage & frequency',
          m.postCheckVoltFreq,
        ),
        _bulletRow(
          'Inspected exhaust system',
          m.postInspectExhaust,
        ),
        _bulletRow(
          'Verified grounding & bonding',
          m.postVerifyGrounding,
        ),
        _bulletRow(
          'Checked control panel operation',
          m.postCheckControlPanel,
        ),
        _bulletRow(
          'Ensured safety devices are in place & functional',
          m.postEnsureSafetyDevices,
        ),
        _bulletRow(
          'Documented all deficiencies & recommendations',
          m.postDocumentDeficiencies,
        ),
        _bulletRow(
          'Performed load-bank test (if applicable)',
          m.postLoadbankTest,
        ),
        _bulletRow(
          'Verified ATS functionality',
          m.postAtsFunctionality,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Fuel Storage',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        _bulletRow(
          'Fuel stored longer than recommended (consider testing / conditioning)',
          m.fuelStoredLong,
        ),
      ],
    );
  }

  pw.Widget _buildMaintenanceParts(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Parts & Materials Used',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        _maintLabelValueRow(
          'Oil – type & quantity:',
          m.partsOilTypeQty,
          wrap: true,
        ),
        _maintLabelValueRow(
          'Coolant – type & quantity:',
          m.partsCoolantTypeQty,
          wrap: true,
        ),
        _maintLabelValueRow(
          'Filters – types installed:',
          m.partsFilterTypes,
          wrap: true,
        ),
        _maintLabelValueRow(
          'Battery – type / install date:',
          m.partsBatteryTypeDate,
          wrap: true,
        ),
        _maintLabelValueRow(
          'Belts / hoses replaced:',
          m.partsBeltsHosesReplaced,
          wrap: true,
        ),
        _maintLabelValueRow(
          'Block heater – wattage / details:',
          m.partsBlockHeaterWattage,
          wrap: true,
        ),
        _maintLabelValueRow(
          'CDVR – serial / part info:',
          m.partsCdvrSerial,
          wrap: true,
        ),
      ],
    );
  }

  pw.Widget _buildMaintenanceSignatures(MaintenanceRecord m) {
    final techDate = m.technicianSignatureDate != null
        ? _fmtDate(m.technicianSignatureDate!)
        : '';
    final custDate = m.customerSignatureDate != null
        ? _fmtDate(m.customerSignatureDate!)
        : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Signatures',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Technician',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  _maintLabelValueRow(
                    'Name:',
                    m.technicianSignatureName,
                    labelWidth: 40,
                  ),
                  _maintLabelValueRow('Date:', techDate, labelWidth: 40),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    height: 0.5,
                    color: PdfColors.grey600,
                  ),
                  pw.Text(
                    'Technician Signature',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Customer / Site Representative',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  _maintLabelValueRow(
                    'Name:',
                    m.customerSignatureName,
                    labelWidth: 40,
                  ),
                  _maintLabelValueRow('Date:', custDate, labelWidth: 40),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    height: 0.5,
                    color: PdfColors.grey600,
                  ),
                  pw.Text(
                    'Customer Signature',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Note: Drawn signatures may be captured digitally and overlaid or attached separately.',
          style: const pw.TextStyle(fontSize: 7),
        ),
      ],
    );
  }

  // ---------- Storage + email/share helper ----------

  Future<PdfExportResult> _saveAndMaybeEmailPdf({
    required List<int> bytes,
    required String fileName,
    required PdfExportPrefs prefs,
  }) async {
    String? savePath;

    if (kIsWeb) {
      // On web you’ll typically trigger a download from the UI.
      // We just return here without a concrete path.
      return const PdfExportResult(filePath: null, emailed: false);
    }

    // MOBILE / DESKTOP
    io.Directory baseDir;

    if (prefs.customDirectoryPath != null) {
      baseDir = io.Directory(prefs.customDirectoryPath!);
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
    } else {
      // Use an app-safe directory
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        baseDir = await getApplicationSupportDirectory();
      } else {
        // Windows, macOS, Linux etc.
        baseDir = await getApplicationDocumentsDirectory();
      }
    }

    final appDir = io.Directory(
      p.join(baseDir.path, prefs.appSubfolder),
    );
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

    await Share.shareXFiles(
      [xFile],
      subject: 'Generator Service Report',
      text: prefs.defaultRecipient != null
          ? 'Please see attached generator report for your records.'
          : 'Please see attached generator report.',
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
    // final techSigPath = maintenance.technicianSignaturePath;
    // final customerSigPath = maintenance.customerSignaturePath;
    //
    // if (techSigPath != null && io.File(techSigPath).existsSync()) {
    //   final dest =
    //       p.join(folderPath, 'tech_signature_${maintenance.id}.png');
    //   await io.File(techSigPath).copy(dest);
    // }
    //
    // if (customerSigPath != null && io.File(customerSigPath).existsSync()) {
    //   final dest =
    //       p.join(folderPath, 'customer_signature_${maintenance.id}.png');
    //   await io.File(customerSigPath).copy(dest);
    // }
  }
}
