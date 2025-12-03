import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Reusable PDF template components matching the A&S Electric template
class PdfTemplate {
  // Color scheme matching the template
  static const headerGray = PdfColor.fromInt(0xFF666666);
  static const lightGray = PdfColor.fromInt(0xFFE0E0E0);
  static const darkBlue = PdfColor.fromInt(0xFF1a3a52);

  /// Company header with logo and contact info
  static pw.Widget companyHeader({pw.MemoryImage? logo}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo placeholder
          if (logo != null)
            pw.Container(
              width: 60,
              height: 60,
              child: pw.Image(logo),
            )
          else
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(
                  'A&S\nELECTRIC\nINC',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          pw.SizedBox(width: 16),
          // Company info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'A&S ELECTRIC INC',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '952 Flushing Ave Suite #3 Brooklyn NY 11206',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'office@aselectricnyc.com • www.aselectricnyc.com',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  '(718) 821-1211',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Main title
  static pw.Widget documentTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Section header with gray background
  static pw.Widget sectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: headerGray,
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// Checkbox (checked or unchecked)
  static pw.Widget checkbox(bool checked) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
        color: checked ? PdfColors.black : PdfColors.white,
      ),
      child: checked
          ? pw.Center(
        child: pw.CustomPaint(
          size: const PdfPoint(8, 8),
          painter: (canvas, size) {
            // Draw checkmark (correct orientation)
            canvas
              ..setStrokeColor(PdfColors.white)
              ..setLineWidth(1.5)
              ..moveTo(1, 4)
              ..lineTo(3, 6.5)
              ..lineTo(7, 1.5)
              ..strokePath();
          },
        ),
      )
          : null,
    );
  }

  /// Checkbox with label (inline)
  static pw.Widget checkboxWithLabel(String label, bool checked) {
    return pw.Row(
      children: [
        checkbox(checked),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  /// Yes/No/Unknown/N/A selector
  static pw.Widget yesNoSelector(String value) {
    final isYes = value == 'Yes';
    final isNo = value == 'No';
    final isUnknown = value == 'Unknown';
    final isNA = value == 'N/A';

    return pw.Row(
      children: [
        checkbox(isYes),
        pw.SizedBox(width: 2),
        pw.Text('Yes', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 6),
        checkbox(isNo),
        pw.SizedBox(width: 2),
        pw.Text('No', style: const pw.TextStyle(fontSize: 8)),
        if (isUnknown || isNA) ...[
          pw.SizedBox(width: 6),
          checkbox(isUnknown),
          pw.SizedBox(width: 2),
          pw.Text('Unknown', style: const pw.TextStyle(fontSize: 8)),
        ],
        if (isNA) ...[
          pw.SizedBox(width: 6),
          checkbox(isNA),
          pw.SizedBox(width: 2),
          pw.Text('N/A', style: const pw.TextStyle(fontSize: 8)),
        ],
      ],
    );
  }

  /// Field label and value in a row
  static pw.Widget labelValue(String label, String value, {bool bold = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  /// Create a simple infra table with checkbox support
  static pw.Widget dataTable({
    required List<String> headers,
    required List<List<dynamic>> rows, // Changed to dynamic to support widgets
    List<double>? columnWidths,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600),
      columnWidths: columnWidths != null
          ? Map.fromIterables(
        List.generate(columnWidths.length, (i) => i),
        columnWidths.map((w) => pw.FlexColumnWidth(w)),
      )
          : null,
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: lightGray),
          children: headers
              .map(
                (h) => pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          )
              .toList(),
        ),
        // Data rows
        ...rows.map(
              (row) => pw.TableRow(
            children: row
                .map(
                  (cell) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: cell is pw.Widget
                    ? pw.Align(
                  alignment: pw.Alignment.center,
                  child: cell,
                )
                    : pw.Text(
                  cell.toString(),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Form field table (label on left, value on right)
  static pw.Widget formFieldsTable(Map<String, String> fields) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: fields.entries
          .map(
            (entry) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '${entry.key}:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                entry.value,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      )
          .toList(),
    );
  }

  /// Signature block with image
  static pw.Widget signatureBlock({
    required String label,
    required String name,
    String? signaturePath,
    String? date,
  }) {
    pw.Widget signatureImage;

    try {
      if (signaturePath != null &&
          signaturePath.isNotEmpty &&
          File(signaturePath).existsSync()) {
        final bytes = File(signaturePath).readAsBytesSync();
        signatureImage = pw.Container(
          height: 60,
          child: pw.Image(
            pw.MemoryImage(bytes),
            fit: pw.BoxFit.contain,
          ),
        );
      } else {
        signatureImage = pw.SizedBox(height: 60);
      }
    } catch (_) {
      signatureImage = pw.SizedBox(height: 60);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: signatureImage,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          name.isNotEmpty ? name : '_' * 40,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Date: ${date ?? '_' * 20}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  /// Checklist item with checkbox
  static pw.Widget checklistItem(String label, bool checked) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          checkbox(checked),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  /// Multi-select location checkboxes
  static pw.Widget locationCheckboxes({
    required bool indoors,
    required bool outdoors,
    required bool roof,
    required bool basement,
    required String other,
  }) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        checkboxWithLabel('Indoors', indoors),
        checkboxWithLabel('Outdoors', outdoors),
        checkboxWithLabel('Roof', roof),
        checkboxWithLabel('Basement', basement),
        if (other.isNotEmpty)
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              checkbox(true),
              pw.SizedBox(width: 4),
              pw.Text('Other: $other', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
      ],
    );
  }

  /// Text input field with underline
  static pw.Widget inputField(String value, {double width = 100}) {
    return pw.Container(
      width: width,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(
          value.isNotEmpty ? value : ' ',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    );
  }

  /// Footer for each page
  static pw.Widget pageFooter(int pageNumber) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Text(
        'Page $pageNumber',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  /// Load test readings table (complex grid)
  static pw.Widget loadTestTable({
    required List<Map<String, String>> readings,
  }) {
    final headers = [
      'TEST READING INTERVALS',
      'START',
      '15min',
      '30min',
      '45min',
      '60min',
      '75min',
      '90min',
      '105min',
      '120min',
    ];

    final rows = [
      'REALTIME',
      'TARGET KILOWATT LOADING',
      'ENGINE SPEED·R.P.M.',
      'FREQUENCY·HERTZ',
      'ENGINE WATER °F',
      'RADIATOR WATER TEMPERATURE °F',
      'ENGINE OIL TEMPERATURE °F',
      'ENGINE OIL PRESSURE·PSI',
      'PANEL METER VOLTAGE READING',
      'MEASURED VOLTAGE',
      'PANEL METER AMPERE READING',
      'MEASURED AMPERES',
      'PANEL METER KILOWATT READING',
      'MEASURED KILOWATT READING',
      'BATTERY VOLTAGE',
      'FUEL PRESSURE',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        for (int i = 1; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerGray),
          children: headers
              .map(
                (h) => pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          )
              .toList(),
        ),
        // Data rows
        ...rows.map(
              (label) => pw.TableRow(
            decoration: const pw.BoxDecoration(color: lightGray),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              // Empty cells for data entry
              for (int i = 1; i < headers.length; i++)
                pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 7)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}