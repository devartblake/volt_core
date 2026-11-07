import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/fleet/domain/entities/vehicle_entity.dart';
import '../../../modules/fleet/domain/entities/vehicle_inspection.dart';
import '../../../modules/fleet/domain/entities/vehicle_maintenance_check.dart';
import '../../../shared/presenter/layout/pdf/pdf_template.dart';
import 'vehicle_report_data.dart';

/// Layout for the vehicle report.
///
/// Same bones as the maintenance report (company header with logo, a summary
/// before the detail, "Page X of Y" footer) but a deliberately more modern
/// look so the two are told apart at a glance: a navy and teal palette, soft
/// rounded cards and pills instead of grey section bars and boxed tables, and
/// status shown as coloured dots rather than checkboxes.
class VehicleReportPdf {
  const VehicleReportPdf._();

  static const _navy = PdfColor.fromInt(0xFF12263F);
  static const _teal = PdfColor.fromInt(0xFF0E7C86);
  static const _surface = PdfColor.fromInt(0xFFF3F6F9);
  static const _line = PdfColor.fromInt(0xFFD5DEE7);
  static const _muted = PdfColor.fromInt(0xFF5B6B7C);
  static const _ok = PdfColor.fromInt(0xFF1E8E5A);
  static const _warn = PdfColor.fromInt(0xFFC77700);
  static const _bad = PdfColor.fromInt(0xFFC62828);
  static const _okBg = PdfColor.fromInt(0xFFE3F4EB);
  static const _warnBg = PdfColor.fromInt(0xFFFFF1DB);
  static const _badBg = PdfColor.fromInt(0xFFFBE4E4);

  static void addTo(
    pw.Document pdf,
    VehicleReportData data, {
    pw.MemoryImage? logo,
  }) {
    final v = data.vehicle;
    final shortId = v.id.length > 8 ? v.id.substring(0, 8) : v.id;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : _runningHeader(v),
        footer: (ctx) => _footer(ctx, v, shortId),
        build: (ctx) => [
          _masthead(v, shortId, logo),
          pw.SizedBox(height: 14),
          _hero(v, data),
          pw.SizedBox(height: 12),
          _snapshot(data),
          pw.SizedBox(height: 18),
          _details(v),
          pw.SizedBox(height: 18),
          _inspections(data),
          pw.SizedBox(height: 18),
          _maintenance(data),
          pw.SizedBox(height: 18),
          _tools(data),
          ..._signatures(data),
          ..._photos('Vehicle photos', data.vehiclePhotos),
          ..._photos('Latest inspection photos', data.inspectionPhotos),
          if (v.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Notes'),
            pw.SizedBox(height: 6),
            pw.Text(v.notes.trim(), style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- chrome

  static pw.Widget _masthead(
    VehicleEntity v,
    String shortId,
    pw.MemoryImage? logo,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(width: 38, height: 38, child: pw.Image(logo))
            else
              pw.Container(
                width: 38,
                height: 38,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'A&S',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'A&S ELECTRIC INC',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  pw.Text(
                    '952 Flushing Ave Suite #3 Brooklyn NY 11206  |  (718) 821-1211',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'VEHICLE REPORT',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _teal,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.Text(
                  '${_date(DateTime.now())}  |  No. $shortId',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // Accent rule: navy block, then teal, then hairline.
        pw.Row(
          children: [
            pw.Container(width: 70, height: 3, color: _navy),
            pw.Container(width: 30, height: 3, color: _teal),
            pw.Expanded(child: pw.Container(height: 1, color: _line)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _runningHeader(VehicleEntity v) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'VEHICLE REPORT',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _teal,
              letterSpacing: 1.2,
            ),
          ),
          pw.Text(
            v.displayTitle,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, VehicleEntity v, String shortId) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: PdfTemplate.brandFooter(
        segments: ['A&S ELECTRIC INC', 'Vehicle Report', v.displayTitle, 'No. $shortId'],
        pageNumber: ctx.pageNumber,
        total: ctx.pagesCount,
        bleedX: 28, // page margins: 28 left/right, 30 bottom
        bleedBottom: 30,
      ),
    );
  }

  // ------------------------------------------------------------------ hero

  static pw.Widget _hero(VehicleEntity v, VehicleReportData data) {
    final sub = [
      v.vehicleType.label,
      if (v.makeModel.isNotEmpty) v.makeModel,
      if (v.modelYear != null) '${v.modelYear}',
    ].join('  |  ');

    final (statusFg, statusBg) = switch (v.status) {
      VehicleStatus.active => (_ok, _okBg),
      VehicleStatus.maintenance => (_warn, _warnBg),
      VehicleStatus.retired => (_muted, _surface),
      _ => (_bad, _badBg),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  v.displayTitle,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  sub,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFFB9C7D8),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    _pill(v.status.label, statusFg, statusBg),
                    pw.SizedBox(width: 6),
                    _pill(
                      data.driverName == null
                          ? 'No driver assigned'
                          : 'Driver: ${data.driverName}',
                      _navy,
                      PdfColors.white,
                    ),
                    if (v.licensePlate.trim().isNotEmpty) ...[
                      pw.SizedBox(width: 6),
                      _pill('Plate ${v.licensePlate.trim()}', _navy,
                          PdfColors.white),
                    ],
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                '${v.odometer}',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'MILES',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColor.fromInt(0xFFB9C7D8),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Four tiles: what is due, and what is wrong.
  static pw.Widget _snapshot(VehicleReportData data) {
    final weekly =
        InspectionStatus.compute(InspectionCadence.weekly, data.inspections);
    final monthly =
        InspectionStatus.compute(InspectionCadence.monthly, data.inspections);
    final latest = data.inspections.isEmpty ? null : data.inspections.first;
    final flagged = latest?.issueCount ?? 0;
    final toolsAttention = data.assets
        .where((a) => a.status != 'FMC' && a.status.isNotEmpty)
        .length;

    pw.Widget tile(
      String label,
      String value,
      String sub,
      PdfColor color,
      PdfColor bg,
    ) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ),
        );

    (String, String, PdfColor, PdfColor) due(InspectionStatus s) =>
        switch (s.state) {
          InspectionDueState.never => ('Not done', 'No record yet', _bad, _badBg),
          InspectionDueState.overdue => (
              'Overdue',
              'Was due ${_date(s.dueAt!)}',
              _bad,
              _badBg
            ),
          InspectionDueState.dueSoon => (
              'Due soon',
              'Due ${_date(s.dueAt!)}',
              _warn,
              _warnBg
            ),
          InspectionDueState.ok => (
              'Up to date',
              'Next ${_date(s.dueAt!)}',
              _ok,
              _okBg
            ),
        };

    final w = due(weekly);
    final m = due(monthly);

    return pw.Row(
      children: [
        tile('WEEKLY INSPECTION', w.$1, w.$2, w.$3, w.$4),
        pw.SizedBox(width: 8),
        tile('MONTHLY INSPECTION', m.$1, m.$2, m.$3, m.$4),
        pw.SizedBox(width: 8),
        tile(
          'FLAGGED ITEMS',
          latest == null ? '-' : '$flagged',
          latest == null ? 'No inspection' : 'On latest inspection',
          flagged > 0 ? _bad : _ok,
          flagged > 0 ? _badBg : _okBg,
        ),
        pw.SizedBox(width: 8),
        tile(
          'TOOLS',
          data.assets.isEmpty ? '-' : '${data.assets.length}',
          data.assets.isEmpty
              ? 'None assigned'
              : (toolsAttention == 0
                  ? 'All ready'
                  : '$toolsAttention need attention'),
          toolsAttention > 0 ? _bad : _ok,
          toolsAttention > 0 ? _badBg : _okBg,
        ),
      ],
    );
  }

  // --------------------------------------------------------------- details

  static pw.Widget _details(VehicleEntity v) {
    final items = <(String, String)>[
      ('Designation', v.designation.trim().isEmpty ? v.displayTitle : v.designation),
      ('Type', v.vehicleType.label),
      ('Make / model', v.makeModel),
      ('Year', v.modelYear == null ? '' : '${v.modelYear}'),
      ('VIN', v.vin ?? ''),
      ('License plate', v.licensePlate.trim()),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Vehicle details'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Wrap(
            runSpacing: 6,
            children: [
              for (final (label, value) in items)
                pw.SizedBox(
                  width: 250,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 80,
                        child: pw.Text(
                          label,
                          style: const pw.TextStyle(fontSize: 9, color: _muted),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          value.isEmpty ? 'Not recorded' : value,
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: value.isEmpty ? _muted : _navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- inspections

  static pw.Widget _inspections(VehicleReportData data) {
    final list = data.inspections;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Inspections'),
        pw.SizedBox(height: 6),
        if (list.isEmpty)
          _empty('No inspections recorded yet.')
        else ...[
          for (final i in list.take(8)) _inspectionRow(i),
          pw.SizedBox(height: 10),
          _latestChecklist(list.first),
        ],
      ],
    );
  }

  static pw.Widget _inspectionRow(VehicleInspection i) {
    final clear = !i.hasIssues;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 66,
            child: pw.Text(
              _date(i.inspectedAt),
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
          ),
          _pill(
            i.cadence.label,
            _teal,
            const PdfColor.fromInt(0xFFE0F2F3),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              [
                if (i.inspectorName.isNotEmpty) i.inspectorName,
                if (i.odometer > 0) '${i.odometer} mi',
              ].join('  |  '),
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
          _pill(
            clear ? 'All clear' : '${i.issueCount} flagged',
            clear ? _ok : _bad,
            clear ? _okBg : _badBg,
          ),
        ],
      ),
    );
  }

  /// The most recent inspection item by item, with status dots.
  static pw.Widget _latestChecklist(VehicleInspection i) {
    final items = inspectionItemsFor(i.cadence);

    pw.Widget dot(CheckStatus s) {
      final color = switch (s) {
        CheckStatus.ok => _ok,
        CheckStatus.attention => _warn,
        CheckStatus.fail => _bad,
      };
      return pw.Container(
        width: 8,
        height: 8,
        decoration: pw.BoxDecoration(
          color: color,
          shape: pw.BoxShape.circle,
        ),
      );
    }

    pw.Widget entry(InspectionItem item) {
      final status = i.results[item.key] ?? CheckStatus.ok;
      final note = i.itemNotes[item.key] ?? '';
      return pw.SizedBox(
        width: 248,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2.5),
                  child: dot(status),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    item.label,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                          status.needsFollowUp ? pw.FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            ),
            if (status.needsFollowUp && note.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 14, top: 1),
                child: pw.Text(
                  note,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: status == CheckStatus.fail ? _bad : _warn,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'Latest: ${i.cadence.label.toLowerCase()} inspection, ${_date(i.inspectedAt)}',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.Spacer(),
              _legend('OK', _ok),
              pw.SizedBox(width: 8),
              _legend('Attention', _warn),
              pw.SizedBox(width: 8),
              _legend('Failed', _bad),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [for (final item in items) entry(item)],
          ),
          if (i.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Notes: ${i.notes.trim()}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _signatures(VehicleReportData data) {
    final driver = data.driverSignature;
    final dispatcher = data.dispatcherSignature;
    if ((driver == null || driver.isEmpty) &&
        (dispatcher == null || dispatcher.isEmpty)) {
      return const [];
    }

    pw.Widget box(String label, Uint8List? bytes) {
      pw.MemoryImage? image;
      if (bytes != null && bytes.isNotEmpty) {
        try {
          image = pw.MemoryImage(bytes);
        } catch (_) {
          image = null;
        }
      }
      return pw.Expanded(
        child: pw.Container(
          height: 70,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: image == null
                    ? pw.Center(
                        child: pw.Text(
                          'Not signed',
                          style: const pw.TextStyle(fontSize: 9, color: _muted),
                        ),
                      )
                    : pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
              ),
              pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    return [
      pw.SizedBox(height: 18),
      _heading('Signatures (latest inspection)'),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          box('Assigned person', driver),
          pw.SizedBox(width: 12),
          box('Dispatcher', dispatcher),
        ],
      ),
    ];
  }

  static List<pw.Widget> _photos(String title, List<VehicleReportPhoto> photos) {
    final images = <(pw.MemoryImage, String)>[];
    for (final photo in photos) {
      try {
        images.add((pw.MemoryImage(photo.bytes), photo.caption));
      } catch (_) {
        // Skip images the PDF library cannot decode.
      }
    }
    if (images.isEmpty) return const [];

    return [
      pw.SizedBox(height: 18),
      _heading(title),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (image, caption) in images)
            pw.Container(
              width: 240,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(image, width: 240, height: 180, fit: pw.BoxFit.cover),
                  if (caption.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(caption, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ],
              ),
            ),
        ],
      ),
    ];
  }

  static pw.Widget _legend(String label, PdfColor color) => pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
        ],
      );

  // ----------------------------------------------------------- maintenance

  static pw.Widget _maintenance(VehicleReportData data) {
    final checks = data.checks;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Maintenance history'),
        pw.SizedBox(height: 6),
        if (checks.isEmpty)
          _empty('No maintenance checks recorded yet.')
        else
          _ruleTable(
            headers: const ['Date', 'Odometer', 'Brakes', 'Battery', 'Notes'],
            widths: const [1.4, 1.3, 1.3, 1.3, 4],
            rows: [
              for (final c in checks.take(10))
                [
                  _text(_date(c.checkedAt.toLocal()), bold: true),
                  _text('${c.odometer} mi'),
                  _status(c.brakeStatus),
                  _status(c.batteryStatus),
                  _text(c.notes),
                ],
            ],
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- tools

  static pw.Widget _tools(VehicleReportData data) {
    final tools = data.assets;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Tools & equipment'),
        pw.SizedBox(height: 6),
        if (tools.isEmpty)
          _empty('No tools assigned to this vehicle.')
        else
          _ruleTable(
            headers: const ['Tool', 'Serial', 'Status', 'Notes'],
            widths: const [3.6, 2, 1.4, 3],
            rows: [
              for (final t in tools)
                [
                  _text(t.label, bold: true),
                  _text(t.serial),
                  _toolStatus(t.status),
                  _text(t.notes),
                ],
            ],
          ),
      ],
    );
  }

  // --------------------------------------------------------------- helpers

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static pw.Widget _heading(String text) => pw.Row(
        children: [
          pw.Container(width: 4, height: 14, color: _teal),
          pw.SizedBox(width: 7),
          pw.Text(
            text.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
              letterSpacing: 1,
            ),
          ),
        ],
      );

  static pw.Widget _empty(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      );

  static pw.Widget _pill(String text, PdfColor fg, PdfColor bg) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: fg,
          ),
        ),
      );

  static pw.Widget _text(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: pw.Text(
          text.isEmpty ? '-' : text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? _navy : null,
          ),
        ),
      );

  static pw.Widget _status(CheckStatus s) {
    final (fg, bg) = switch (s) {
      CheckStatus.ok => (_ok, _okBg),
      CheckStatus.attention => (_warn, _warnBg),
      CheckStatus.fail => (_bad, _badBg),
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: _pill(s.label, fg, bg),
      ),
    );
  }

  static pw.Widget _toolStatus(String status) {
    final good = status == 'FMC';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: _pill(
          status.isEmpty ? '-' : status,
          good ? _ok : _bad,
          good ? _okBg : _badBg,
        ),
      ),
    );
  }

  /// Table with a coloured header and hairline row separators, no cell boxes.
  static pw.Widget _ruleTable({
    required List<String> headers,
    required List<double> widths,
    required List<List<pw.Widget>> rows,
  }) {
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < widths.length; i++) i: pw.FlexColumnWidth(widths[i]),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.6),
        bottom: pw.BorderSide(color: _line, width: 0.6),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(6),
              topRight: pw.Radius.circular(6),
            ),
          ),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: pw.Text(
                  h.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
          ],
        ),
        for (final row in rows) pw.TableRow(children: row),
      ],
    );
  }
}
