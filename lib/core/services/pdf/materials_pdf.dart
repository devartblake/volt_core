import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/materials/domain/material_item.dart';
import '../../../modules/materials/domain/material_list.dart';
import '../../../shared/presenter/layout/pdf/pdf_template.dart';

/// The Parts & Materials table printed on inspection and maintenance reports.
class MaterialsPdf {
  const MaterialsPdf._();

  static const _zebra = PdfColor.fromInt(0xFFF5F5F5);
  static const _flag = PdfColor.fromInt(0xFFB3261E);

  static String _date(DateTime? d) => d == null
      ? '-'
      : '${d.month.toString().padLeft(2, '0')}/'
          '${d.day.toString().padLeft(2, '0')}/${d.year}';

  /// Items in slot order, primary first, blank ones left out.
  static List<MaterialItem> ordered(List<MaterialItem> items) => [
        for (final slot in MaterialSlot.values)
          ...MaterialListOps.forSlot(items, slot).where((i) => !i.isBlank),
      ];

  static pw.Widget _cell(String text, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text.isEmpty ? '-' : text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );

  /// A titled section, or an empty widget when nothing is listed.
  ///
  /// [showDue] adds a column marking parts flagged for replacement (used on
  /// inspections, where it says what the follow-up job needs).
  static pw.Widget section(
    List<MaterialItem> items, {
    String title = 'Parts & Materials',
    String dateLabel = 'Date used',
    bool showDue = false,
  }) {
    final rows = ordered(items);
    if (rows.isEmpty) return pw.SizedBox();

    final headers = [
      'Part',
      'Part number',
      'Name / manufacturer',
      'Qty',
      dateLabel,
      if (showDue) 'Due',
    ];
    final widths = <double>[2.6, 2.2, 3.4, 0.8, 1.6, if (showDue) 0.9];

    String nameOf(MaterialItem i) {
      final name = i.partName.trim();
      final maker = i.manufacturer.trim();
      if (name.isNotEmpty && maker.isNotEmpty) return '$name ($maker)';
      return name.isNotEmpty ? name : maker;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader(title),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
          columnWidths: {
            for (var i = 0; i < widths.length; i++)
              i: pw.FlexColumnWidth(widths[i]),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfTemplate.lightGray),
              children: [for (final h in headers) _cell(h, bold: true)],
            ),
            for (var n = 0; n < rows.length; n++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: n.isOdd ? _zebra : PdfColors.white,
                ),
                children: [
                  _cell(
                    rows[n].role == MaterialRole.none
                        ? rows[n].slot.label
                        : '${rows[n].slot.label} (${rows[n].role.label})',
                    bold: true,
                  ),
                  _cell(rows[n].partNumber),
                  _cell(nameOf(rows[n])),
                  _cell('${rows[n].quantity}'),
                  _cell(_date(rows[n].dateUsed)),
                  if (showDue)
                    _cell(
                      rows[n].needsReplacement ? 'Yes' : '',
                      bold: rows[n].needsReplacement,
                      color: rows[n].needsReplacement ? _flag : null,
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
