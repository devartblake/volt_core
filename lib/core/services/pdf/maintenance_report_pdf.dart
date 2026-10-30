import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/maintenance/infra/models/maintenance_record.dart';
import '../../../shared/presenter/layout/pdf/pdf_template.dart';

/// Layout for the generator maintenance report.
///
/// Shares the company header, section bars and checkbox look of the inspection
/// report ([PdfTemplate]) but is organised around what a maintenance visit
/// produces rather than what an inspection asks:
///
/// 1. a summary of what was found and done (so a reader needn't dig),
/// 2. the equipment and walkthrough context,
/// 3. condition findings with the recommended action beside each,
/// 4. the work actually performed, with notes,
/// 5. post-service verification,
/// 6. parts used, follow-up, and sign-off.
///
/// Text sticks to Latin-1: the built-in PDF font cannot draw en dashes or
/// bullets, which previously printed as missing glyphs.
class MaintenanceReportPdf {
  const MaintenanceReportPdf._();

  static const _flag = PdfColor.fromInt(0xFFB3261E);
  static const _flagBg = PdfColor.fromInt(0xFFFCE8E6);
  static const _ok = PdfColor.fromInt(0xFF2E6B3A);
  static const _zebra = PdfColor.fromInt(0xFFF5F5F5);

  /// Builds the report pages onto [pdf].
  static void addTo(
    pw.Document pdf,
    MaintenanceRecord m, {
    pw.MemoryImage? logo,
    pw.MemoryImage? technicianSignature,
    pw.MemoryImage? customerSignature,
  }) {
    final shortId = m.id.length > 8 ? m.id.substring(0, 8) : m.id;
    final site = m.siteCode.isEmpty ? 'No site code' : m.siteCode;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : _runningHeader(site, m),
        footer: (ctx) => _footer(ctx, shortId, site),
        build: (ctx) => [
          PdfTemplate.companyHeader(logo: logo),
          PdfTemplate.documentTitle('Generator Maintenance & Repair Report'),
          _metaStrip(m, shortId),
          pw.SizedBox(height: 10),
          _summary(m),
          pw.SizedBox(height: 12),
          _siteAndEquipment(m),
          pw.SizedBox(height: 12),
          _walkthrough(m),
          pw.SizedBox(height: 12),
          _findings(m),
          pw.SizedBox(height: 12),
          _partsNeeded(m),
          _workPerformed(m),
          pw.SizedBox(height: 12),
          _postService(m),
          pw.SizedBox(height: 12),
          _partsUsed(m),
          pw.SizedBox(height: 12),
          _followUp(m),
          pw.SizedBox(height: 14),
          _signOff(m, technicianSignature, customerSignature),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- chrome

  static pw.Widget _runningHeader(String site, MaintenanceRecord m) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'A&S ELECTRIC INC - Maintenance Report',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '$site   ${_date(m.dateOfService ?? m.createdAt)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, String shortId, String site) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Report $shortId   $site',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  /// One-line identity of the visit: where, when, who, and how it ended.
  static pw.Widget _metaStrip(MaintenanceRecord m, String shortId) {
    final status = m.requiresFollowUp
        ? 'FOLLOW-UP REQUIRED'
        : (m.completed ? 'COMPLETED' : 'IN PROGRESS');
    final statusColor = m.requiresFollowUp
        ? _flag
        : (m.completed ? _ok : PdfColors.grey700);

    pw.Widget cell(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(value.isEmpty ? '-' : value,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _zebra,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          cell('SITE', m.siteCode),
          cell('DATE OF SERVICE', _date(m.dateOfService ?? m.createdAt)),
          cell('TECHNICIAN', m.technicianName),
          cell('REPORT NO.', shortId),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('STATUS',
                    style: const pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(
                  status,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- summary

  static List<_Finding> _computeFindings(MaintenanceRecord m) {
    final out = <_Finding>[];

    out.add(_Finding(
      'Battery',
      m.batteryNeedsReplace
          ? 'Needs replacement'
          : (m.batteryRecentlyReplaced ? 'Recently replaced' : 'No issue noted'),
      _join([
        if (m.batteryType.isNotEmpty) 'Type ${m.batteryType}',
        if (m.batteryPartNo.isNotEmpty) 'P/N ${m.batteryPartNo}',
        if (m.batteryMfgDate.isNotEmpty) 'Mfg ${m.batteryMfgDate}',
      ]),
      m.batteryNeedsReplace ? 'Replace battery' : '',
      m.batteryNeedsReplace,
    ));

    out.add(_Finding(
      'Air filter',
      m.airFilterNeedsReplace
          ? 'Needs replacement'
          : (m.airFilterRecentlyReplaced ? 'Recently replaced' : 'No issue noted'),
      _join([
        if (m.airFilterPartNo.isNotEmpty) 'P/N ${m.airFilterPartNo}',
        if (m.airFilterLastReplacedDate.isNotEmpty)
          'Last replaced ${m.airFilterLastReplacedDate}',
      ]),
      m.airFilterNeedsReplace ? 'Replace air filter' : '',
      m.airFilterNeedsReplace,
    ));

    out.add(_Finding(
      'Coolant',
      m.coolantLevel.isEmpty ? 'Not recorded' : 'Level ${m.coolantLevel}',
      m.coolantColor.isEmpty ? '' : 'Color ${m.coolantColor}',
      '',
      false,
    ));

    void hose(String name, bool compromised, bool recommend, String info) {
      out.add(_Finding(
        name,
        compromised ? 'Compromised' : 'No issue noted',
        info,
        recommend ? 'Recommend change' : '',
        compromised || recommend,
      ));
    }

    hose('Coolant hoses', m.coolantHosesCompromised,
        m.coolantHosesRecommendChange, m.coolantHosesInfo);
    hose('Fuel hoses', m.fuelHosesCompromised, m.fuelHosesRecommendChange,
        m.fuelHosesInfo);
    hose('Air intake hoses', m.airIntakeHosesCompromised,
        m.airIntakeHosesRecommendChange, m.airIntakeHosesInfo);
    hose('Oil hoses', m.oilHosesCompromised, m.oilHosesRecommendChange,
        m.oilHosesInfo);
    hose('Additional hoses', m.additionalHosesCompromised,
        m.additionalHosesRecommendChange, m.additionalHosesInfo);

    return out;
  }

  static List<_Action> _actions(MaintenanceRecord m) => [
        _Action('Oil filter changed', m.oilFilterChanged, m.oilFilterNotes),
        _Action('Fuel filter replaced', m.fuelFilterReplaced, m.fuelFilterNotes),
        _Action('Coolant flushed / topped off', m.coolantFlushed, m.coolantNotes),
        _Action('Battery replaced / serviced', m.batteryReplaced, m.batteryNotes),
        _Action('Air filter replaced', m.airFilterReplaced, m.airFilterNotes),
        _Action('Belts / hoses replaced', m.beltsHosesReplaced, m.beltsHosesNotes),
        _Action('Block heater tested and functional', m.blockHeaterTested,
            m.blockHeaterNotes),
        _Action('Racor / fuel-water separator serviced', m.racorServiced,
            m.racorNotes),
        _Action('ATS / controller inspected', m.atsControllerInspected,
            m.atsControllerNotes),
        _Action('CDVR programmed / calibrated', m.cdvrProgrammed, m.cdvrNotes),
        _Action('Under-voltage issue repaired', m.undervoltageRepaired,
            m.undervoltageNotes),
        _Action('Hazardous material removed / disposed', m.hazmatRemoved,
            m.hazmatNotes),
      ];

  static List<_Part> _partsList(MaintenanceRecord m) => [
        _Part('Lube filter', m.canLube, m.canLubePartNo),
        _Part('Fuel filter', m.canFuel, m.canFuelPartNo),
        _Part('Water separator', m.canWaterSep, m.canWaterSepPartNo),
        _Part('Oil filter', m.canOil, m.canOilPartNo),
        _Part(m.canOther1Label.isEmpty ? 'Other 1' : m.canOther1Label,
            m.canOther1, m.canOther1PartNo),
        _Part(m.canOther2Label.isEmpty ? 'Other 2' : m.canOther2Label,
            m.canOther2, m.canOther2PartNo),
      ];

  /// What a reader wants first: how much was done, what needs attention.
  static pw.Widget _summary(MaintenanceRecord m) {
    final actions = _actions(m);
    final done = actions.where((a) => a.done).length;
    final flagged = _computeFindings(m).where((f) => f.flag).toList();
    final needed = _partsList(m).where((p) => p.needed).length;

    pw.Widget stat(String value, String label, {bool alert = false}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: alert ? _flagBg : PdfColors.white,
              border: pw.Border.all(color: alert ? _flag : PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: alert ? _flag : PdfColors.black,
                  ),
                ),
                pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Service Summary'),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            stat('$done / ${actions.length}', 'maintenance actions performed'),
            pw.SizedBox(width: 6),
            stat('${flagged.length}', 'findings needing attention',
                alert: flagged.isNotEmpty),
            pw.SizedBox(width: 6),
            stat('$needed', 'filters / parts to order', alert: needed > 0),
            pw.SizedBox(width: 6),
            stat(m.requiresFollowUp ? 'Yes' : 'No', 'follow-up visit required',
                alert: m.requiresFollowUp),
          ],
        ),
        if (flagged.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'Needs attention: ${flagged.map((f) => f.component).join(', ')}',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _flag),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- sections

  static pw.Widget _siteAndEquipment(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Site & Generator'),
        pw.SizedBox(height: 6),
        _pairs([
          ('Site code', m.siteCode),
          ('Address', m.address),
          ('Generator make', m.generatorMake),
          ('Model', m.generatorModel),
          ('Serial no.', m.generatorSerial),
          ('Rated output (kW)', m.generatorKw),
          ('Voltage rating', m.voltageRating),
          ('Fuel type', m.fuelType),
          ('Engine hours', m.engineHours),
          ('Last fuel delivery', m.lastFuelDeliveryDate),
        ]),
      ],
    );
  }

  static pw.Widget _walkthrough(MaintenanceRecord m) {
    final loc = m.generatorLocation;
    final location =
        loc == 'Other' && m.generatorLocationOther.isNotEmpty
            ? '$loc (${m.generatorLocationOther})'
            : loc;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Walkthrough & Site Safety'),
        pw.SizedBox(height: 6),
        _pairs([('Generator location', location)]),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _checkGroup('Enclosure', [
                ('Intact', m.enclosureIntact),
                ('Damaged', m.enclosureDamaged),
                ('No enclosure', m.noEnclosure),
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 2,
              child: _checkGroup('Safety & hazards', [
                ('Visible damage or leaks', m.visibleDamageOrLeaks),
                ('Area clear of debris / tripping hazards',
                    m.areaClearOfHazards),
                ('Warning / safety labels visible', m.warningLabelsVisible),
                ('Fire extinguisher present and accessible',
                    m.fireExtinguisherPresent),
              ], alertWhenTrue: const {'Visible damage or leaks'}),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _findings(MaintenanceRecord m) {
    final rows = _computeFindings(m);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Condition Findings'),
        pw.SizedBox(height: 6),
        _table(
          headers: const ['Component', 'Condition', 'Details', 'Recommended'],
          widths: const [2.2, 2.2, 3.6, 2.2],
          rows: [
            for (final f in rows)
              [
                _cell(f.component, bold: true),
                _cell(f.condition, color: f.flag ? _flag : null, bold: f.flag),
                _cell(f.details),
                _cell(f.action, color: f.flag ? _flag : null, bold: f.flag),
              ],
          ],
        ),
      ],
    );
  }

  /// Filters / canisters to order, listed only when some are needed.
  static pw.Widget _partsNeeded(MaintenanceRecord m) {
    final needed = _partsList(m).where((p) => p.needed).toList();
    if (needed.isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfTemplate.sectionHeader('Filters & Parts To Order'),
          pw.SizedBox(height: 6),
          _table(
            headers: const ['Item', 'Part number'],
            widths: const [4, 6],
            rows: [
              for (final p in needed)
                [_cell(p.label, bold: true), _cell(p.partNo)],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _workPerformed(MaintenanceRecord m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Work Performed'),
        pw.SizedBox(height: 6),
        _table(
          headers: const ['Task', 'Done', 'Notes'],
          widths: const [5, 1, 5],
          rows: [
            for (final a in _actions(m))
              [
                _cell(a.label),
                pw.Center(child: PdfTemplate.checkbox(a.done)),
                _cell(a.notes),
              ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _postService(MaintenanceRecord m) {
    final items = <(String, bool)>[
      ('Generator runs under load', m.postVerifyRunsUnderLoad),
      ('Voltage and frequency checked', m.postCheckVoltFreq),
      ('Exhaust system inspected', m.postInspectExhaust),
      ('Grounding and bonding verified', m.postVerifyGrounding),
      ('Control panel operation checked', m.postCheckControlPanel),
      ('Safety devices in place and functional', m.postEnsureSafetyDevices),
      ('Deficiencies and recommendations documented',
          m.postDocumentDeficiencies),
      ('Load-bank test performed (if applicable)', m.postLoadbankTest),
      ('ATS functionality verified', m.postAtsFunctionality),
    ];
    final half = (items.length / 2).ceil();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Post-Service Verification'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _checkGroup(null, items.sublist(0, half))),
            pw.SizedBox(width: 16),
            pw.Expanded(child: _checkGroup(null, items.sublist(half))),
          ],
        ),
        pw.SizedBox(height: 6),
        _checkGroup('Fuel storage', [
          (
            'Fuel stored longer than recommended (consider testing / conditioning)',
            m.fuelStoredLong
          ),
        ], alertWhenTrue: const {
          'Fuel stored longer than recommended (consider testing / conditioning)'
        }),
      ],
    );
  }

  static pw.Widget _partsUsed(MaintenanceRecord m) {
    final rows = <(String, String)>[
      ('Oil (type and quantity)', m.partsOilTypeQty),
      ('Coolant (type and quantity)', m.partsCoolantTypeQty),
      ('Filters installed', m.partsFilterTypes),
      ('Battery (type / install date)', m.partsBatteryTypeDate),
      ('Belts / hoses replaced', m.partsBeltsHosesReplaced),
      ('Block heater (wattage / details)', m.partsBlockHeaterWattage),
      ('CDVR (serial / part info)', m.partsCdvrSerial),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Parts & Materials Used'),
        pw.SizedBox(height: 6),
        _table(
          headers: const ['Item', 'Details'],
          widths: const [4, 6],
          rows: [
            for (final r in rows) [_cell(r.$1, bold: true), _cell(r.$2)],
          ],
        ),
      ],
    );
  }

  static pw.Widget _followUp(MaintenanceRecord m) {
    final observations = m.serviceObservations.trim();
    final followNotes = (m.followUpNotes ?? '').trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTemplate.sectionHeader('Observations & Follow-up'),
        pw.SizedBox(height: 6),
        _label('Service observations'),
        _box(observations),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            PdfTemplate.checkboxWithLabel(
                'Follow-up visit required', m.requiresFollowUp),
            pw.SizedBox(width: 20),
            PdfTemplate.checkboxWithLabel('Job completed', m.completed),
          ],
        ),
        if (m.requiresFollowUp || followNotes.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _label('Follow-up notes'),
          _box(followNotes, alert: m.requiresFollowUp),
        ],
      ],
    );
  }

  static pw.Widget _signOff(
    MaintenanceRecord m,
    pw.MemoryImage? technicianSignature,
    pw.MemoryImage? customerSignature,
  ) {
    pw.Widget block(
      String role,
      String name,
      DateTime? date,
      pw.MemoryImage? image,
    ) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(role,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 46,
              alignment: pw.Alignment.bottomLeft,
              child: image == null
                  ? null
                  : pw.Image(image, height: 44, fit: pw.BoxFit.contain),
            ),
            pw.Container(height: 0.6, color: PdfColors.grey700),
            pw.SizedBox(height: 3),
            pw.Text(name.isEmpty ? 'Name: ____________________' : 'Name: $name',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              date == null ? 'Date: ____________________' : 'Date: ${_date(date)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );
    }

    // Keep the sign-off together so a signature never lands alone on a page
    // away from the statement it confirms.
    return pw.Wrap(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            PdfTemplate.sectionHeader('Sign-off'),
            pw.SizedBox(height: 6),
            pw.Text(
              'The technician confirms the work above was performed as recorded. '
              'The site representative confirms the visit took place and that '
              'the findings and recommendations were explained.',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                block('Technician', m.technicianSignatureName,
                    m.technicianSignatureDate, technicianSignature),
                pw.SizedBox(width: 28),
                block('Customer / Site Representative', m.customerSignatureName,
                    m.customerSignatureDate, customerSignature),
              ],
            ),
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

  static String _join(List<String> parts) => parts.join(', ');

  static pw.Widget _label(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  /// A bordered, growing text area; blank still shows as a writable box.
  static pw.Widget _box(String text, {bool alert = false}) => pw.Container(
        width: double.infinity,
        constraints: const pw.BoxConstraints(minHeight: 40),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: alert ? _flagBg : null,
          border: pw.Border.all(color: alert ? _flag : PdfColors.grey600),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

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

  static pw.Widget _table({
    required List<String> headers,
    required List<double> widths,
    required List<List<pw.Widget>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: {
        for (var i = 0; i < widths.length; i++) i: pw.FlexColumnWidth(widths[i]),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfTemplate.lightGray),
          children: [
            for (final h in headers) _cell(h, bold: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _zebra : PdfColors.white,
            ),
            children: rows[i],
          ),
      ],
    );
  }

  /// Label/value pairs laid out two to a row.
  static pw.Widget _pairs(List<(String, String)> items) {
    pw.Widget pair((String, String) item) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 92,
                  child: pw.Text(item.$1,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Text(item.$2.isEmpty ? '-' : item.$2,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
        );

    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pair(items[i]),
          pw.SizedBox(width: 12),
          i + 1 < items.length ? pair(items[i + 1]) : pw.Expanded(child: pw.SizedBox()),
        ],
      ));
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _checkGroup(
    String? title,
    List<(String, bool)> items, {
    Set<String> alertWhenTrue = const {},
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (title != null) _label(title),
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PdfTemplate.checkbox(item.$2),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(
                    item.$1,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: item.$2 && alertWhenTrue.contains(item.$1)
                          ? _flag
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Finding {
  const _Finding(
      this.component, this.condition, this.details, this.action, this.flag);

  final String component;
  final String condition;
  final String details;
  final String action;

  /// Whether this row needs attention (drives colour and the summary count).
  final bool flag;
}

class _Action {
  const _Action(this.label, this.done, this.notes);

  final String label;
  final bool done;
  final String notes;
}

class _Part {
  const _Part(this.label, this.needed, this.partNo);

  final String label;
  final bool needed;
  final String partNo;
}
