import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:voltcore/core/services/pdf/materials_pdf.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

void main() {
  final items = [
    const MaterialItem(
      id: '1',
      slot: MaterialSlot.oilFilter,
      role: MaterialRole.primary,
      partNumber: 'OF-1',
      partName: 'Spin-on oil filter',
      manufacturer: 'Fleetguard',
      quantity: 2,
    ),
    MaterialItem(
      id: '2',
      slot: MaterialSlot.battery,
      partNumber: 'B-27',
      dateUsed: DateTime(2026, 11, 3),
      needsReplacement: true,
    ),
    const MaterialItem(id: '3', slot: MaterialSlot.airFilter), // blank
  ];

  test('blank items are left out and the rest are in slot order', () {
    final out = MaterialsPdf.ordered(items);
    expect(out.map((i) => i.id), ['1', '2']);
  });

  test('nothing listed prints nothing', () {
    expect(MaterialsPdf.section(const []), isA<pw.SizedBox>());
  });

  test('the table renders into a document, with and without the due column',
      () async {
    for (final showDue in [false, true]) {
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        build: (_) => [MaterialsPdf.section(items, showDue: showDue)],
      ));
      final bytes = await pdf.save();
      expect(bytes.length, greaterThan(500));
    }
  });
}
