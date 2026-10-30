import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/hive/hive_adapters.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';

/// Guards the printed inspection report: content that is longer than the
/// fixed layouts assumed must flow onto more pages, never throw or be cut off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_ins_pdf_layout');
    Hive.init(dir.path);
    HiveAdapters.registerAll();
    await HiveBoxes.init();
  });
  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Long, but within what a technician really types for one field.
  final long = List.filled(6, 'Detailed technician remark about this item.')
      .join(' ');
  final veryLong = List.filled(40, 'Detailed technician remark about this item.')
      .join(' ');

  Inspection full() => Inspection(
        id: 'ins-1',
        createdAt: DateTime(2026, 10, 30),
        siteCode: 'BK-0042-LONG-SITE-CODE',
        siteGrade: 'Amber',
        address: '952 Flushing Avenue Suite 3 Brooklyn New York 11206 $long',
        technicianName: 'Sam Technician With A Rather Long Name',
        generatorMake: 'Cummins Power Generation',
        generatorModel: 'C150D6 Series Extended',
        generatorSerial: 'SN-1234567890-ABCDEFG',
        notes: veryLong,
        customerName: 'Customer Representative With Long Name',
      )..checklistNotes = {
          for (final k in [
            'genset_runs_under_load',
            'voltage_frequency_ok',
            'exhaust_ok',
            'grounding_bonding_ok',
            'control_panel_ok',
            'safety_devices_ok',
            'deficiencies_documented',
            'loadbank_done',
            'ats_verified',
            'fuel_stored_over_1yr',
          ])
            k: long,
        };

  test('builds with worst-case text and flows onto extra pages', () async {
    final bytes = await PdfService.instance.buildInspectionPdfBytes(full());
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final pages = RegExp(r'/Type\s*/Page[^s]')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;
    // Five fixed pages plus the overflow pages.
    expect(pages, greaterThan(5));
  });

  test('builds for an empty record', () async {
    final bytes = await PdfService.instance.buildInspectionPdfBytes(
      Inspection(id: 'ins-2', createdAt: DateTime(2026, 10, 30)),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('the optional summary page is added only when requested', () async {
    int pagesFor(List<int> bytes) => RegExp(r'/Type\s*/Page[^s]')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .length;

    final base = Inspection(
      id: 'ins-3',
      createdAt: DateTime(2026, 10, 30),
      siteCode: 'BK-1',
    );
    final without = await PdfService.instance
        .buildInspectionPdfBytes(base, includeSummary: false);
    final withSummary = await PdfService.instance
        .buildInspectionPdfBytes(base, includeSummary: true);

    expect(pagesFor(withSummary), pagesFor(without) + 1);
  });
}
