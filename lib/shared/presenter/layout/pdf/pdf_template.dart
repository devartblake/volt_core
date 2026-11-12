import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/services/storage/file_storage_service.dart';
import '../../../../core/services/storage/path_resolver.dart';

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
            // PDF canvas coordinates increase upward. The prior points used
            // screen coordinates, which rendered the selected tick as a ^.
            canvas
              ..setStrokeColor(PdfColors.white)
              ..setLineWidth(1.5)
              ..moveTo(1, 4)
              ..lineTo(3, 1.5)
              ..lineTo(7, 6.5)
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
        pw.Text('Yes', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(width: 6),
        checkbox(isNo),
        pw.SizedBox(width: 2),
        pw.Text('No', style: const pw.TextStyle(fontSize: 9)),
        if (isUnknown || isNA) ...[
          pw.SizedBox(width: 6),
          checkbox(isUnknown),
          pw.SizedBox(width: 2),
          pw.Text('Unknown', style: const pw.TextStyle(fontSize: 9)),
        ],
        if (isNA) ...[
          pw.SizedBox(width: 6),
          checkbox(isNA),
          pw.SizedBox(width: 2),
          pw.Text('N/A', style: const pw.TextStyle(fontSize: 9)),
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
      // Cross-platform read: WebFileStore on web, filesystem (with stale-path
      // re-anchoring) on native.
      final bytes = (signaturePath != null && signaturePath.isNotEmpty)
          ? FileStorageService.readSignatureBytesSync(
              PathResolver.resolveSync(signaturePath))
          : null;
      if (bytes != null) {
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

  /// Footer navy (matches `assets/images/pdf_footer.svg`, traced from the company checklist) and the two text
  /// colours used on it.
  ///
  /// The text alternates between white and a pale ice blue, a tint of the navy
  /// and map so the lettering sits in the same colour family as the artwork.
  /// Both are far lighter than the navy, so on a black-and-white printer the band becomes a dark
  /// grey and both colours stay clearly readable on it; in colour the
  /// alternation makes the separate items easy to tell apart.
  static const footerBlue = PdfColor.fromInt(0xFF0E2841);
  static const footerTextA = PdfColors.white;
  static const footerTextB = PdfColor.fromInt(0xFFD2E6FA);

  /// Height of the whole band at the artwork's own proportions (612 wide).
  static const double footerBandHeight = 73.28;

  static String? _footerSvg;
  static Uint8List? _footerLogoBytes;

  /// The A&S Electric company logo (the one in the PDF header) in a pale colour
  /// so it stands apart from the navy band. Made by `tool/make_footer_logo.py`.
  /// The app logo is not used in PDFs. Single source for the footer logo.
  static const footerLogoAsset = 'assets/images/company_logo_footer.png';

  /// The band's top edge is stepped: along the left (where the logo and text
  /// sit) it is only this tall; the taller part is on the right.
  static const double footerLeftBandHeight = 45.58;

  /// Logo height as a share of that left band height (its width follows the
  /// image's own proportions), and the gap before the text.
  static const double footerLogoScale = 0.84;
  static const double footerLogoGap = 8;
  static const double _footerPadX = 12;

  /// Overrides the footer artwork (tests and artwork previews).
  static void useFooterArt(String? svg) => _footerSvg = svg;

  /// Overrides the footer logo with PNG bytes (tests); null drops the logo.
  static void useFooterLogo(Uint8List? png) => _footerLogoBytes = png;

  /// Loads the footer artwork so [brandFooter] can draw it. Call once before
  /// building a document; without it the footer is a plain solid band.
  static Future<void> loadFooterArt() async {
    if (_footerLogoBytes == null) {
      try {
        _footerLogoBytes = (await rootBundle.load(footerLogoAsset)).buffer.asUint8List();
      } catch (e) {
        debugPrint('[PdfTemplate] Footer logo not available, drawing without it: $e');
      }
    }
    if (_footerSvg != null) return;
    try {
      _footerSvg = await rootBundle.loadString('assets/images/pdf_footer.svg');
    } catch (e) {
      debugPrint('[PdfTemplate] Footer art not available, using solid band: $e');
    }
  }

  /// The footer logo with its size, or null when the asset is missing or is
  /// not a valid PNG (the footer then renders without it instead of failing).
  static ({pw.Widget widget, double width, double height})? _footerLogoLayout() {
    final bytes = _footerLogoBytes;
    if (bytes == null) return null;
    try {
      // PNG header: 8-byte signature, then IHDR with width and height.
      if (bytes.length < 24 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
        throw const FormatException('not a PNG');
      }
      final data = ByteData.sublistView(bytes);
      final w = data.getUint32(16).toDouble();
      final h = data.getUint32(20).toDouble();
      if (w <= 0 || h <= 0) throw const FormatException('empty image');
      const height = footerLeftBandHeight * footerLogoScale;
      final width = height * w / h;
      final image = pw.MemoryImage(bytes);
      return (
        widget: pw.Image(image, width: width, height: height, fit: pw.BoxFit.contain),
        width: width,
        height: height,
      );
    } catch (e) {
      debugPrint('[PdfTemplate] Footer logo is not usable, skipping: $e');
      return null;
    }
  }

  /// The footer logo widget, or null (see [_footerLogoLayout]).
  static pw.Widget? footerLogo() => _footerLogoLayout()?.widget;

  /// Footer band: the stepped navy artwork, with text in
  /// alternating colours on top.
  ///
  /// [segments] are laid out left to right and coloured white, amber, white...
  /// The page number sits on the right in bold, in the next colour in turn.
  ///
  /// [bleedX] and [bleedBottom] are the page margins to grow into, so the band
  /// runs edge to edge instead of stopping at the margin. Pass the margins of
  /// the page the footer sits on.
  static pw.Widget brandFooter({
    required List<String> segments,
    required int pageNumber,
    int? total,
    double bleedX = 0,
    double bleedBottom = 0,
  }) {
    pw.Widget text(String value, int index, {bool bold = false, bool oneLine = false}) => pw.Text(
          value,
          maxLines: oneLine ? 1 : null,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: index.isEven ? footerTextA : footerTextB,
          ),
        );

    final page = total == null ? 'Page $pageNumber' : 'Page $pageNumber of $total';
    final svg = _footerSvg;
    final layout = _footerLogoLayout();
    final logo = layout?.widget;

    return pw.Container(
      width: double.infinity,
      // The band reaches [bleedBottom] below this box, so the box is shorter.
      height: footerBandHeight - bleedBottom,
      child: pw.Stack(
        // The band deliberately reaches past the margins.
        overflow: pw.Overflow.visible,
        children: [
          pw.Positioned(
            left: -bleedX,
            right: -bleedX,
            top: 0,
            bottom: -bleedBottom,
            child: svg == null
                ? pw.Container(color: footerBlue)
                : pw.SvgImage(svg: svg, fit: pw.BoxFit.fill),
          ),
          if (logo != null)
            pw.Positioned(
              left: _footerPadX,
              // Vertically centred in the left part of the band (the band
              // starts at the box top).
              top: footerBandHeight - footerLeftBandHeight + (footerLeftBandHeight - layout!.height) / 2,
              child: logo,
            ),
          pw.Positioned(
            left: _footerPadX + (layout != null ? layout.width + footerLogoGap : 0),
            right: _footerPadX,
            bottom: 18 - bleedBottom, // measured from the band's bottom edge
            child: pw.Row(
              children: [
                // Long site / title text is clipped to one line rather than
                // running into the page number.
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0) pw.SizedBox(width: 14),
                        if (i == 0)
                          text(segments[i], i, bold: true)
                        else
                          pw.Flexible(child: text(segments[i], i, oneLine: true)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                text(page, segments.length, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Footer for each page: company name, phone and the page number.
  static pw.Widget pageFooter(
    int pageNumber, {
    int? total,
    double bleedX = 0,
    double bleedBottom = 0,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: brandFooter(
        segments: const ['A&S ELECTRIC INC', '(718) 821-1211'],
        pageNumber: pageNumber,
        total: total,
        bleedX: bleedX,
        bleedBottom: bleedBottom,
      ),
    );
  }

  /// Load test readings table (complex grid)
  /// [fillHeight], when given, stretches the data rows so the whole table is
  /// at least that tall (used to fill most of the page for hand-written
  /// readings). Without it the rows keep their compact height.
  static pw.Widget loadTestTable({
    required List<Map<String, String>> readings,
    double? fillHeight,
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

    const headerHeight = 24.0;
    final rowHeight = fillHeight == null
        ? 0.0
        : ((fillHeight - headerHeight) / rows.length).ceilToDouble();
    final fontSize = fillHeight == null ? 7.0 : 8.0;

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
                  fontSize: fontSize,
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
              pw.Container(
                constraints: pw.BoxConstraints(minHeight: rowHeight),
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              // Empty cells for data entry
              for (int i = 1; i < headers.length; i++)
                pw.Container(
                  constraints: pw.BoxConstraints(minHeight: rowHeight),
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('', style: pw.TextStyle(fontSize: fontSize)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
