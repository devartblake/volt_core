import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/import/parts_import.dart';
import 'package:voltcore/modules/inventory/domain/import/sheet_reader.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

SheetData sheet(String name, List<List<String>> rows) => SheetData(name, rows);

/// A tiny tracker in the real layout: slot headings, sub-headings, generators.
SheetData tracker(List<List<String>> generators) {
  const sub = ['Part Number', 'QTY Used', 'Date Used', 'Part Name'];
  return sheet('Q tracker', [
    ['School', 'Air Filter', '', '', '', 'Battery', '', '', '', 'Coolant Filter', '', '', ''],
    ['', ...sub, ...sub, ...sub],
    ...generators.map((g) => [...g, ...List.filled(13 - g.length, '')]),
  ]);
}

void main() {
  group('cleaning', () {
    test('text: invisible characters, odd spaces and runs of spaces', () {
      expect(cleanText('  P55​3000  '), 'P553000');
      expect(cleanText('a \t b\n c'), 'a b c');
    });

    test('placeholders are not part numbers', () {
      for (final s in ['N/A', 'n/a', '-', '?', '', ' none ', 'TBD']) {
        expect(cleanPartNumber(s), '', reason: s);
      }
    });

    test('part numbers are upper-cased and tidied', () {
      expect(cleanPartNumber(' p553000 '), 'P553000');
      expect(cleanPartNumber('253108.0'), '253108');
      expect(cleanPartNumber('Part #: bf5810'), 'BF5810');
    });

    test('suspicious part numbers are flagged', () {
      final w = <String>[];
      cleanPartNumber('2A-17 0-SL', warnings: w);
      expect(w, isNotEmpty);
      final e = <String>[];
      cleanPartNumber('1.2E+7', warnings: e);
      expect(e.single, contains('scientific'));
    });

    test('battery specs written differently become one spec', () {
      const want = '8D-MHD CCA 1400 RC 450';
      for (final s in [
        '8D-MHD CCA 1400 RC450',
        '8D-MHD 1400 CCA RC 450',
        '8d-mhd  cca1400  rc 450',
      ]) {
        expect(cleanBatterySpec(s), want, reason: s);
      }
      expect(cleanBatterySpec('4D-XHD 1000 CCA RC 295'),
          '4D-XHD CCA 1000 RC 295');
    });

    test('manufacturer spellings are unified', () {
      expect(knownManufacturer('Detriot Diesel'), 'Detroit Diesel');
      expect(knownManufacturer('FleetGuard'), 'Fleetguard');
      expect(knownManufacturer('Racor/Parker'), 'Racor');
      expect(knownManufacturer('Fuel Pump Asmbly'), isNull);
    });

    test('column headings map to slots', () {
      expect(slotFromText('Fuel Filter (Primary)'), MaterialSlot.fuelFilter);
      expect(slotFromText('Fuel/Water Seperator'),
          MaterialSlot.fuelWaterSeparator);
      expect(slotFromText('Racor Filter (fuel/water separator)'),
          MaterialSlot.racorFilter);
      expect(slotFromText('Lube Filter (Secondary)'), MaterialSlot.lubeFilter);
      expect(slotFromText('Battery '), MaterialSlot.battery);
      expect(slotFromText('Additional Part #2'), MaterialSlot.additionalParts);
      expect(slotFromText('Battery Charger'), isNull);
    });
  });

  group('tracker layout', () {
    test('reads parts, merges repeats, counts generators', () {
      final r = parseInventorySheets([
        tracker([
          ['Q005', 'PA2650', '1', '', 'Baldwin', '8D-MHD CCA 1400 RC450', '2', '', 'Interstate'],
          ['Q082', 'pa2650', '1', '', 'Baldwin', '8D-MHD 1400 CCA RC 450', '2', '', 'Interstate'],
          ['Q089', 'N/A', '', '', '', '', '', '', ''],
        ]),
      ]);
      expect(r.sheetsRead.keys, ['Q tracker']);
      expect(r.parts.map((p) => p.partNumber).toSet(),
          {'PA2650', '8D-MHD CCA 1400 RC 450'});
      final air = r.parts.firstWhere((p) => p.partNumber == 'PA2650');
      expect(air.slot, MaterialSlot.airFilter);
      expect(air.manufacturer, 'Baldwin');
      expect(air.uses, 2);
      final bat = r.parts.firstWhere((p) => p.slot == MaterialSlot.battery);
      expect(bat.manufacturer, 'Interstate');
      expect(r.skipped.any((s) => s.value == 'N/A'), isTrue);
    });

    test('a description in the name column is kept as the name', () {
      final r = parseInventorySheets([
        sheet('T', [
          ['School', 'Air Filter', '', '', '', 'Battery', '', '', '', 'Additional Part #1', '', '', ''],
          ['', 'Part Number', 'QTY Used', 'Date Used', 'Part Name', 'Part Number', 'QTY Used', 'Date Used', 'Part Name', 'Part Number', 'QTY Used', 'Date Used', 'Part Name'],
          ['Q1', '', '', '', '', '', '', '', '', 'GM100971', '1', '', 'Fuel Pump Asmbly'],
        ]),
      ]);
      final p = r.parts.single;
      expect(p.name, 'Fuel Pump Asmbly');
      expect(p.manufacturer, '');
    });

    test('a part listed under two manufacturers keeps the commoner, warns', () {
      final r = parseInventorySheets([
        tracker([
          ['A', 'P1', '1', '', 'Donaldson', '', '', '', ''],
          ['B', 'P1', '1', '', 'Donaldson', '', '', '', ''],
          ['C', 'P1', '1', '', 'Baldwin', '', '', '', ''],
        ]),
      ]);
      final p = r.parts.single;
      expect(p.manufacturer, 'Donaldson');
      expect(p.issues.single.message, contains('manufacturers'));
    });
  });


  group('generator parts lists', () {
    const sub = ['Part Number', 'QTY Used', 'Date Used', 'Part Name'];
    SheetData gen(List<List<String>> rows) => sheet('Q', [
          [
            'School', 'Make', 'Model', 'Serial Number',
            'Fuel Filter (Primary)', '', '', '',
            'Fuel Filter (Secondary)', '', '', '',
            'Battery', '', '', '',
          ],
          ['', '', '', '', ...sub, ...sub, ...sub],
          ...rows,
        ]);

    test('builds a list per generator with roles, quantities and dates', () {
      final r = parseInventorySheets([
        gen([
          ['Q005', 'kohler', '250REOZD', '738968', 'BF5810', '1', '', 'Baldwin',
           'p551329', '', '45000', 'Donaldson', '8D-MHD CCA 1400 RC450', '2', '', 'Interstate'],
        ]),
      ]);
      final g = r.generators.single;
      expect(g.key, 'kohler|250reozd|738968');
      expect(g.make, 'Kohler');
      expect(g.items.length, 3);
      final fuel = g.items.where((i) => i.slot == MaterialSlot.fuelFilter).toList();
      expect(fuel.map((i) => i.role.wire), ['primary', 'secondary']);
      expect(fuel.last.partNumber, 'P551329');
      expect(fuel.last.quantity, 1); // blank means one
      expect(fuel.last.dateUsed, DateTime.utc(2023, 3, 15));
      final bat = g.items.firstWhere((i) => i.slot == MaterialSlot.battery);
      expect(bat.partNumber, '8D-MHD CCA 1400 RC 450');
      expect(bat.quantity, 2);
      expect(bat.manufacturer, 'Interstate');
      expect(g.items.map((i) => i.id).toSet().length, 3);
    });

    test('a row that cannot be identified is reported, its parts kept', () {
      final r = parseInventorySheets([
        gen([
          ['Q1', '', '', '', 'BF1', '1', '', '', '', '', '', '', '', '', '', ''],
          ['Q2', 'Cummins', '100DGDB', 'A1', 'BF2', '1', '', '', '', '', '', '', '', '', '', ''],
        ]),
      ]);
      expect(r.generators.map((g) => g.site), ['Q2']);
      expect(r.parts.map((p) => p.partNumber).toSet(), {'BF1', 'BF2'});
      expect(r.skipped.single.reason, contains('identify the generator'));
    });

    test('the same generator on two rows is read once', () {
      final row = ['Q1', 'Cummins', '100DGDB', 'A1', 'BF2', '1', '', '', '', '', '', '', '', '', '', ''];
      final r = parseInventorySheets([gen([row, row])]);
      expect(r.generators, hasLength(1));
      expect(r.skipped.single.reason, contains('Listed again'));
    });
  });

  group('flat list', () {
    test('maps headings, cleans, reads quantities and alternates', () {
      final r = parseInventorySheets([
        sheet('Stock', [
          ['Part #', 'Description', 'Brand', 'Min', 'On hand', 'Alt'],
          [' lf3000 ', 'Lube  filter', 'fleetguard', '2', '5', 'P551000; LF-3001'],
          ['', 'orphan row', '', '', '', ''],
          ['BAT-31', 'Battery', '', 'x', '4.6', ''],
        ]),
      ]);
      expect(r.sheetsRead['Stock'], 'Parts list');
      final lf = r.parts.firstWhere((p) => p.partNumber == 'LF3000');
      expect(lf.name, 'Lube filter');
      expect(lf.manufacturer, 'Fleetguard');
      expect(lf.minStock, 2);
      expect(lf.openingQty, 5);
      expect(lf.alternates, ['P551000', 'LF-3001']);
      final bat = r.parts.firstWhere((p) => p.partNumber.startsWith('BAT'));
      expect(bat.openingQty, 5); // 4.6 rounds
      expect(bat.minStock, 0);
      expect(bat.issues, isNotEmpty);
      expect(r.skipped.single.reason, 'No part number');
    });

    test('a sheet with no recognisable columns is reported, not guessed', () {
      final r = parseInventorySheets([
        sheet('Quotes', [
          ['', 'Graybar'],
          ['18/2C', r'$189']
        ]),
      ]);
      expect(r.parts, isEmpty);
      expect(r.sheetsIgnored.keys, ['Quotes']);
    });

    test('CSV input is read the same way', () {
      final sheets = readSpreadsheet(
        Uint8List.fromList(utf8.encode('Part Number,Name\r\n"A,1","Big ""one"""\r\n')),
        fileName: 'parts.csv',
      );
      expect(sheets.single.rows[1], ['A,1', 'Big "one"']);
    });
  });

  group('planning against the catalog', () {
    final t = DateTime.utc(2026);
    final existing = CatalogPart(
        id: '1', partNumber: 'LF3000', createdAt: t, updatedAt: t,
        altPartNumbers: const ['P551000']);

    test('new parts are added, existing ones only get blanks filled', () {
      final r = parseInventorySheets([
        sheet('S', [
          ['Part Number', 'Name', 'Manufacturer'],
          ['lf-3000', 'Lube filter', 'Fleetguard'],
          ['P-551000', '', ''],
          ['ZZ9', 'New', ''],
        ]),
      ]);
      final plan = planImport(r.parts, [existing]);
      final byNumber = {for (final p in plan) p.part.partNumber: p};
      expect(byNumber['LF-3000']!.action, ImportAction.fill);
      expect(byNumber['LF-3000']!.fills, ['manufacturer', 'slot', 'name']);
      expect(byNumber['P-551000']!.action, ImportAction.same);
      expect(byNumber['ZZ9']!.action, ImportAction.add);
    });
  });

  test('the real Queens/Bronx tracker reads cleanly', () {
    final f = File('assets/Shop Steward Procurement Tracker.xlsx');
    if (!f.existsSync()) return;
    final r = parseInventorySheets(
        readSpreadsheet(f.readAsBytesSync(), fileName: f.path));
    expect(r.sheetsRead.keys,
        containsAll(['Q_MaintenanceMaterialTracker', 'X_MaintenanceMaterialTracker']));
    expect(r.parts.length, greaterThan(100));
    // No placeholders or duplicates slipped through.
    expect(r.parts.any((p) => isPlaceholder(p.partNumber)), isFalse);
    expect(r.parts.map((p) => p.key).toSet().length, r.parts.length);
    expect(r.generators.length, greaterThan(40));
    expect(r.generators.map((g) => g.key).toSet().length, r.generators.length);
    for (final g in r.generators) {
      expect(g.items, isNotEmpty);
      // Every item's part number is one the catalog import also found.
      for (final i in g.items) {
        expect(r.parts.any((p) => p.key == partKey(i.partNumber)), isTrue);
      }
    }
    // ignore: avoid_print
    print('parts=${r.parts.length} skipped=${r.skipped.length} '
        'withWarnings=${r.parts.where((p) => p.issues.isNotEmpty).length} '
        'read=${r.sheetsRead} ignored=${r.sheetsIgnored}');
    for (final p in r.parts.where((p) => p.issues.isNotEmpty).take(25)) {
      // ignore: avoid_print
      print('${p.partNumber}: ${p.issues.map((i) => i.message).join('; ')}');
    }
    for (final s in r.skipped.take(12)) {
      // ignore: avoid_print
      print('skipped ${s.sheet} r${s.row}: ${s.value} (${s.reason})');
    }
  });
}
