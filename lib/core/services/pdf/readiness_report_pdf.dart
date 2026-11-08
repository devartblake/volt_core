import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/readiness/domain/readiness_export_data.dart';
import '../../../modules/readiness/domain/readiness_models.dart';
import '../../../modules/readiness/domain/readiness_rules.dart'
    show readinessDate;
import '../../../modules/readiness/domain/readiness_view.dart';
import '../../../shared/presenter/layout/pdf/pdf_template.dart';

/// Layout for the Fleet Readiness Report: a summary page (the numbers behind
/// the dashboard's donut and its 12-week due chart), then the units grouped
/// Not ready / Needs attention / Due soon / Ready, each with its reasons.
///
/// Same house style as the other reports: company header, navy section bars
/// and the branded footer with "Page X of Y".
class ReadinessReportPdf {
  const ReadinessReportPdf._();

  static const _navy = PdfColor.fromInt(0xFF12263F);
  static const _muted = PdfColor.fromInt(0xFF5B6B7C);
  static const _line = PdfColor.fromInt(0xFFD5DEE7);
  static const _surface = PdfColor.fromInt(0xFFF3F6F9);

  static PdfColor _color(ReadinessStatus s) => switch (s) {
        ReadinessStatus.ready => const PdfColor.fromInt(0xFF1E8E5A),
        ReadinessStatus.dueSoon => const PdfColor.fromInt(0xFF1F6FB5),
        ReadinessStatus.attention => const PdfColor.fromInt(0xFFC77700),
        ReadinessStatus.notReady => const PdfColor.fromInt(0xFFC62828),
      };

  static void addTo(
    pw.Document pdf,
    ReadinessExportData data, {
    pw.MemoryImage? logo,
  }) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: PdfTemplate.brandFooter(
            segments: [
              'A&S ELECTRIC INC',
              'Fleet Readiness Report',
              readinessDate(data.asOf, data.asOf),
            ],
            pageNumber: ctx.pageNumber,
            total: ctx.pagesCount,
            bleedX: 28,
            bleedBottom: 30,
          ),
        ),
        build: (ctx) => [
          PdfTemplate.companyHeader(logo: logo),
          pw.SizedBox(height: 10),
          PdfTemplate.documentTitle('Fleet Readiness Report'),
          pw.SizedBox(height: 4),
          pw.Text(
            'As of ${readinessDate(data.asOf, data.asOf)} ${data.asOf.year}, '
            '${readinessClock(data.asOf)}'
            '${data.filtered ? '  |  Filtered list: ${data.units.length} of ${data.summary.total} units' : ''}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.SizedBox(height: 12),
          _summary(data),
          pw.SizedBox(height: 14),
          _dueTable(data),
          for (final status in ReadinessStatus.values)
            ..._group(status, data),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- summary

  static pw.Widget _summary(ReadinessExportData data) {
    final s = data.summary;
    final pct = s.total == 0 ? '-' : '${s.percentReady.round()}%';
    pw.Widget tile(String value, String label, PdfColor color) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _surface,
              border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
              ],
            ),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Summary'),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          tile(pct, 'ready of ${s.total} generators', _navy),
          for (final st in ReadinessStatus.values.reversed)
            tile('${s.count(st)}', st.label, _color(st)),
        ]),
        pw.SizedBox(height: 6),
        pw.Text(
          '${s.overdueCount} overdue  |  ${s.followUpCount} open follow-ups  |  '
          '${s.partsShortUnits} units with parts short  |  Grades: '
          '${s.gradeCounts[ReadinessGrade.green] ?? 0} Green, '
          '${s.gradeCounts[ReadinessGrade.amber] ?? 0} Amber, '
          '${s.gradeCounts[ReadinessGrade.red] ?? 0} Red, '
          '${s.gradeCounts[ReadinessGrade.none] ?? 0} ungraded',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static pw.Widget _dueTable(ReadinessExportData data) {
    final s = data.summary;
    final rows = <List<String>>[
      ['Overdue', '${s.overdueCount}'],
      for (final b in s.dueByWeek)
        ['Week of ${readinessDate(b.weekStart, data.asOf)}', '${b.count}'],
      ['Later', '${s.dueLater}'],
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Inspections due, next 12 weeks'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            _row(['Week', 'Units due'], header: true),
            for (final r in rows) _row(r),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- units

  static List<pw.Widget> _group(ReadinessStatus status, ReadinessExportData data) {
    final units = [
      for (final u in data.units)
        if (u.status == status) u,
    ];
    if (units.isEmpty) return const [];
    return [
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _color(status),
        child: pw.Text(
          '${status.label} (${units.length})',
          style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1.4),
          2: pw.FlexColumnWidth(1.3),
          3: pw.FlexColumnWidth(1.6),
          4: pw.FlexColumnWidth(3.4),
        },
        children: [
          _row(['Unit', 'Site', 'Last inspected', 'Next due', 'Reasons'],
              header: true),
          for (final u in units)
            _row([
              [
                u.title,
                if (u.serial.isNotEmpty) 'S/N ${u.serial}',
              ].join('\n'),
              u.siteCode.isNotEmpty ? u.siteCode : u.address,
              u.lastInspectionAt == null
                  ? 'Never'
                  : '${readinessDate(u.lastInspectionAt!, data.asOf)}'
                      '${u.lastGrade == ReadinessGrade.none ? '' : ' (${u.lastGrade.label})'}',
              readinessDueText(u),
              [for (final r in u.reasons) r.text].join('\n'),
            ]),
        ],
      ),
    ];
  }

  static pw.TableRow _row(List<String> cells, {bool header = false}) =>
      pw.TableRow(
        decoration:
            header ? const pw.BoxDecoration(color: PdfTemplate.lightGray) : null,
        children: [
          for (final c in cells)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(
                c.isEmpty ? '-' : c,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
        ],
      );
}
