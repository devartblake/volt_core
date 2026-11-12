import 'package:uuid/uuid.dart';

import '../../../materials/domain/material_item.dart';
import '../../../materials/domain/material_list.dart';
import '../catalog_part.dart';
import 'sheet_reader.dart';

/// Cleaning and parsing for spreadsheet imports. Pure functions: nothing here
/// touches storage, so the rules can be tested on their own.

const _uuid = Uuid();

// ---------------------------------------------------------------- cleaning

/// Strips invisible characters, turns odd spaces into plain ones and collapses
/// runs of whitespace.
String cleanText(String s) {
  final t = s
      .replaceAll(RegExp('[​‌‍﻿­]'), '')
      .replaceAll(RegExp('[   \t\r\n]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // A character that could not be decoded at all.
  return t.replaceAll('�', '').trim();
}

const _placeholders = {
  '', 'N/A', 'NA', 'N.A.', 'NONE', 'NULL', 'NIL', '-', '--', '?', '??', 'TBD',
  'UNKNOWN', 'X', '0',
};

/// True for cells that stand for "nothing here".
bool isPlaceholder(String s) => _placeholders.contains(cleanText(s).toUpperCase());

/// Battery specs are written many ways ("8D-MHD CCA 1400 RC450",
/// "4D-MHD 1000 CCA RC 295"). Put them in one shape so they count as one part.
String cleanBatterySpec(String raw) {
  var s = cleanText(raw).toUpperCase();
  final cca = RegExp(r'CCA\s*(\d+)').firstMatch(s) ??
      RegExp(r'(\d+)\s*CCA').firstMatch(s);
  final rc = RegExp(r'RC\s*(\d+)').firstMatch(s) ??
      RegExp(r'(\d+)\s*RC\b').firstMatch(s);
  if (cca == null && rc == null) return s;
  var base = s;
  if (cca != null) base = base.replaceFirst(cca.group(0)!, ' ');
  if (rc != null) base = base.replaceFirst(rc.group(0)!, ' ');
  base = cleanText(base);
  return [
    if (base.isNotEmpty) base,
    if (cca != null) 'CCA ${cca.group(1)}',
    if (rc != null) 'RC ${rc.group(1)}',
  ].join(' ');
}

/// A cleaned part number, or '' when the cell holds no real part number.
/// [warnings] receives anything worth a second look.
String cleanPartNumber(String raw, {MaterialSlot? slot, List<String>? warnings}) {
  var s = cleanText(raw);
  if (isPlaceholder(s)) return '';
  // Excel turns 253108 into "253108.0", and long numbers into 1.2E+7.
  if (RegExp(r'^\d+\.0+$').hasMatch(s)) s = s.split('.').first;
  if (RegExp(r'^\d(\.\d+)?E\+?\d+$', caseSensitive: false).hasMatch(s)) {
    warnings?.add('Looks like Excel changed this number to scientific notation');
  }
  s = s.replaceFirst(RegExp(r'^(part\s*(no\.?|number|#)\s*:?\s*|#)', caseSensitive: false), '');
  if (slot == MaterialSlot.battery) return cleanBatterySpec(s);
  s = s.toUpperCase();
  if (s.length > 40) warnings?.add('Unusually long for a part number');
  if (s.contains(' ')) warnings?.add('Contains a space — check for a typo');
  return s;
}

/// Manufacturer spellings seen in the spreadsheets, and the one to keep.
const _manufacturers = <String, String>{
  'baldwin': 'Baldwin',
  'donaldson': 'Donaldson',
  'fleetguard': 'Fleetguard',
  'fleet guard': 'Fleetguard',
  'interstate': 'Interstate',
  'hotstart': 'HotStart',
  'hot start': 'HotStart',
  'caterpillar': 'Caterpillar',
  'cat': 'Caterpillar',
  'kohler': 'Kohler',
  'generac': 'Generac',
  'john deere': 'John Deere',
  'deere': 'John Deere',
  'parker': 'Parker',
  'racor': 'Racor',
  'racor/parker': 'Racor',
  'parker/racor': 'Racor',
  'bosch': 'Bosch',
  'detroit diesel': 'Detroit Diesel',
  'detriot diesel': 'Detroit Diesel',
  'mtu': 'MTU',
  'cummins': 'Cummins',
  'onan': 'Onan',
  'cummins onan': 'Cummins',
  'mondial': 'Mondial',
  'grainger': 'Grainger',
  'eaton': 'Eaton',
  'asco': 'ASCO',
};

/// The canonical manufacturer, or null when the text is not a known one.
String? knownManufacturer(String raw) =>
    _manufacturers[cleanText(raw).toLowerCase()];

/// Maps a column heading or category word to a material slot.
MaterialSlot? slotFromText(String raw) {
  final s = cleanText(raw).toLowerCase();
  if (s.isEmpty) return null;
  if (s.contains('racor')) return MaterialSlot.racorFilter;
  if (s.contains('water') && (s.contains('sep') || s.contains('fuel'))) {
    return MaterialSlot.fuelWaterSeparator;
  }
  if (s.contains('fuel') && s.contains('filter')) return MaterialSlot.fuelFilter;
  if (s.contains('lube')) return MaterialSlot.lubeFilter;
  if (s.contains('oil') && s.contains('filter')) return MaterialSlot.oilFilter;
  if (s.contains('coolant') && s.contains('filter')) {
    return MaterialSlot.coolantFilter;
  }
  if (s.contains('air') && s.contains('filter')) return MaterialSlot.airFilter;
  if (s.contains('battery') || s.contains('batteries')) {
    if (s.contains('charger')) return null;
    return MaterialSlot.battery;
  }
  if (s.contains('block heater') || s.contains('coolant heater')) {
    return MaterialSlot.blockHeater;
  }
  if (s.contains('additional')) return MaterialSlot.additionalParts;
  return null;
}

// ---------------------------------------------------------------- results

enum ImportSeverity { warning, error }

class ImportNote {
  const ImportNote(this.severity, this.message);
  final ImportSeverity severity;
  final String message;
}

/// A cell or row the importer left out, and why.
class SkippedEntry {
  const SkippedEntry({
    required this.sheet,
    required this.row,
    required this.value,
    required this.reason,
  });

  final String sheet;

  /// 1-based spreadsheet row.
  final int row;
  final String value;
  final String reason;
}

/// One distinct part found in the spreadsheet, after cleaning and merging
/// repeats. [uses] counts how many places (generators, rows) listed it.
class ImportPart {
  ImportPart({
    required this.partNumber,
    this.name = '',
    this.manufacturer = '',
    this.slot,
    this.minStock = 0,
    List<String>? alternates,
    this.notes = '',
    this.openingQty,
    this.uses = 1,
    List<String>? sheets,
    List<ImportNote>? notes2,
  })  : alternates = alternates ?? [],
        sheets = sheets ?? [],
        issues = notes2 ?? [];

  String partNumber;
  String name;
  String manufacturer;
  MaterialSlot? slot;
  int minStock;
  List<String> alternates;
  String notes;

  /// Quantity on hand to record as opening stock, when the sheet has one.
  int? openingQty;
  int uses;
  final List<String> sheets;
  final List<ImportNote> issues;

  String get key => partKey(partNumber);

  void warn(String m) {
    if (!issues.any((i) => i.message == m)) {
      issues.add(ImportNote(ImportSeverity.warning, m));
    }
  }
}

/// One generator read from a tracker row: who it is and the parts it takes.
class GeneratorImport {
  GeneratorImport({
    required this.key,
    required this.site,
    required this.make,
    required this.model,
    required this.serial,
    required this.items,
    this.sheet = '',
    this.row = 0,
    List<ImportNote>? issues,
  }) : issues = issues ?? [];

  /// [generatorProfileKey] of make + model + serial.
  final String key;

  /// The site label from the sheet ("Q005").
  final String site;
  final String make;
  final String model;
  final String serial;
  final List<MaterialItem> items;
  final String sheet;
  final int row;
  final List<ImportNote> issues;

  String get title => [make, model].where((s) => s.isNotEmpty).join(' ');
}

class ParsedImport {
  const ParsedImport({
    required this.parts,
    required this.skipped,
    required this.sheetsRead,
    required this.sheetsIgnored,
    this.generators = const [],
  });

  /// Generators whose parts lists can be built from the file.
  final List<GeneratorImport> generators;

  final List<ImportPart> parts;
  final List<SkippedEntry> skipped;

  /// Sheets a layout was recognised in, with the layout name.
  final Map<String, String> sheetsRead;

  /// Sheets nothing could be read from, with the reason.
  final Map<String, String> sheetsIgnored;

  bool get isEmpty => parts.isEmpty;
}

// ---------------------------------------------------------------- parsing

/// Reads every sheet in a workbook, whichever layout it has, and merges the
/// parts into one list with duplicates folded together.
ParsedImport parseInventorySheets(List<SheetData> sheets) {
  final found = <ImportPart>[];
  final skipped = <SkippedEntry>[];
  final read = <String, String>{};
  final ignored = <String, String>{};
  final gens = <GeneratorImport>[];

  for (final sheet in sheets) {
    final tracker = _parseTracker(sheet, skipped, gens);
    if (tracker != null) {
      found.addAll(tracker);
      read[sheet.name] = 'Maintenance tracker (parts used per generator)';
      continue;
    }
    final flat = _parseFlat(sheet, skipped);
    if (flat != null) {
      found.addAll(flat);
      read[sheet.name] = 'Parts list';
      continue;
    }
    ignored[sheet.name] = 'No part number columns recognised';
  }

  return ParsedImport(
    parts: _merge(found),
    skipped: skipped,
    sheetsRead: read,
    sheetsIgnored: ignored,
    generators: _dedupeGenerators(gens, skipped),
  );
}

/// The "Q_/X_MaintenanceMaterialTracker" layout: a heading row naming the slot
/// ("Air Filter", "Fuel Filter (Primary)"), a sub-heading row, then one row per
/// generator. Each slot owns four columns: part number, quantity used, date
/// used and the manufacturer.
List<ImportPart>? _parseTracker(
  SheetData sheet,
  List<SkippedEntry> skipped,
  List<GeneratorImport> generators,
) {
  int? sub;
  for (var r = 0; r < sheet.rows.length && r < 8; r++) {
    final n = sheet.rows[r]
        .where((c) => cleanText(c).toLowerCase() == 'part number')
        .length;
    if (n >= 3) {
      sub = r;
      break;
    }
  }
  if (sub == null || sub == 0) return null;
  final head = sub - 1;

  // Each slot's columns, keyed by the part-number column.
  final slotCols = <int, MaterialSlot>{};
  final roleCols = <int, MaterialRole>{};
  MaterialSlot? current;
  var currentRole = MaterialRole.none;
  for (var c = 0; c < sheet.width; c++) {
    final h = sheet.cell(head, c);
    if (cleanText(h).isNotEmpty) {
      current = slotFromText(h);
      final low = cleanText(h).toLowerCase();
      currentRole = low.contains('primary')
          ? MaterialRole.primary
          : low.contains('secondary')
              ? MaterialRole.secondary
              : MaterialRole.none;
    }
    if (cleanText(sheet.cell(sub, c)).toLowerCase() == 'part number' &&
        current != null) {
      slotCols[c] = current;
      roleCols[c] = currentRole;
    }
  }
  if (slotCols.isEmpty) return null;

  // Which column names the generator (School / Site / Unit).
  var siteCol = -1;
  for (var c = 0; c < sheet.width; c++) {
    final h = cleanText(sheet.cell(head, c)).toLowerCase();
    if (h == 'school' || h == 'site' || h == 'location' || h == 'unit') {
      siteCol = c;
      break;
    }
  }

  int colNamed(bool Function(String h) test) {
    for (var c = 0; c < sheet.width; c++) {
      if (test(cleanText(sheet.cell(head, c)).toLowerCase())) return c;
    }
    return -1;
  }

  final makeCol = colNamed((h) => h == 'make');
  final modelCol = colNamed((h) => h == 'model');
  final serialCol = colNamed((h) => h.startsWith('serial'));
  String meta(int r, int c) => c < 0 ? '' : cleanText(sheet.cell(r, c));

  final parts = <ImportPart>[];
  for (var r = sub + 1; r < sheet.rows.length; r++) {
    final site = siteCol >= 0 ? cleanText(sheet.cell(r, siteCol)) : 'Row ${r + 1}';
    final items = <MaterialItem>[];
    for (final e in slotCols.entries) {
      final raw = sheet.cell(r, e.key);
      if (cleanText(raw).isEmpty) continue;
      final warnings = <String>[];
      final pn = cleanPartNumber(raw, slot: e.value, warnings: warnings);
      if (pn.isEmpty) {
        skipped.add(SkippedEntry(
          sheet: sheet.name,
          row: r + 1,
          value: cleanText(raw),
          reason: 'No part number (${e.value.label})',
        ));
        continue;
      }
      var name = '';
      var mfr = '';
      final nameRaw = cleanText(sheet.cell(r, e.key + 3));
      if (!isPlaceholder(nameRaw)) {
        final known = knownManufacturer(nameRaw);
        if (known != null) {
          mfr = known;
        } else if (e.value == MaterialSlot.additionalParts) {
          name = nameRaw; // "Fuel Pump Asmbly": what it is, not who made it.
        } else {
          mfr = nameRaw;
          warnings.add('Unrecognised manufacturer "$nameRaw"');
        }
      }
      final p = ImportPart(
        partNumber: pn,
        name: name,
        manufacturer: mfr,
        slot: e.value,
        sheets: [sheet.name],
      );
      for (final w in warnings) {
        p.warn(w);
      }
      _sites[p] = site;
      parts.add(p);

      final qty = _whole(sheet.cell(r, e.key + 1));
      items.add(MaterialItem(
        id: _uuid.v4(),
        slot: e.value,
        role: roleCols[e.key] ?? MaterialRole.none,
        partNumber: pn,
        partName: name.isNotEmpty && name != e.value.label ? name : '',
        manufacturer: mfr,
        quantity: qty ?? 1,
        dateUsed: _excelDate(sheet.cell(r, e.key + 2)),
      ));
    }

    final make = meta(r, makeCol);
    final model = meta(r, modelCol);
    final serial = cleanPartNumber(meta(r, serialCol));
    final key = generatorProfileKey(
        make: make, model: model, serial: serial);
    if (items.isEmpty) continue;
    if (key.isEmpty) {
      skipped.add(SkippedEntry(
        sheet: sheet.name,
        row: r + 1,
        value: site,
        reason: 'Parts list not built: no make, model or serial to '
            'identify the generator',
      ));
      continue;
    }
    generators.add(GeneratorImport(
      key: key,
      site: site,
      make: knownManufacturer(make) ?? make,
      model: model,
      serial: serial,
      items: MaterialListOps.forSaving(items),
      sheet: sheet.name,
      row: r + 1,
    ));
  }
  return parts;
}

/// A whole quantity, or null when the cell is blank or not a number.
int? _whole(String raw) {
  final t = cleanText(raw);
  if (t.isEmpty) return null;
  final d = double.tryParse(t);
  if (d == null || d < 0) return null;
  return d.round();
}

/// An Excel date serial (days since 1899-12-30) as a date; null for anything
/// else, including text like "N/A".
DateTime? _excelDate(String raw) {
  final d = double.tryParse(cleanText(raw));
  if (d == null || d < 25000 || d > 80000) return null;
  return DateTime.utc(1899, 12, 30).add(Duration(days: d.floor()));
}

/// The same generator listed twice (same make, model and serial) keeps its
/// first row; the repeat is reported.
List<GeneratorImport> _dedupeGenerators(
  List<GeneratorImport> all,
  List<SkippedEntry> skipped,
) {
  final seen = <String>{};
  final out = <GeneratorImport>[];
  for (final g in all) {
    if (seen.add(g.key)) {
      out.add(g);
    } else {
      skipped.add(SkippedEntry(
        sheet: g.sheet,
        row: g.row,
        value: g.site,
        reason: 'Listed again: ${g.title} ${g.serial} already read from an '
            'earlier row',
      ));
    }
  }
  return out;
}

/// Where each parsed part was seen, so usage counts distinct generators.
final _sites = Expando<String>('importSite');

const _syn = <String, List<String>>{
  'partNumber': [
    'part number', 'part no', 'part #', 'part#', 'pn', 'p/n', 'part',
    'item number', 'item #', 'item no', 'sku', 'mfr part', 'mfr part number',
  ],
  'name': ['name', 'part name', 'description', 'item', 'item name', 'desc'],
  'manufacturer': ['manufacturer', 'mfr', 'mfg', 'brand', 'make'],
  'slot': ['category', 'type', 'slot', 'group', 'kind'],
  'min': [
    'min', 'minimum', 'min stock', 'min qty', 'reorder', 'reorder point',
    'reorder level', 'par', 'par level',
  ],
  'qty': [
    'qty', 'quantity', 'on hand', 'qty on hand', 'stock', 'count', 'in stock',
  ],
  'alts': [
    'alternate', 'alternates', 'alt', 'alt part', 'alt part number',
    'cross reference', 'cross ref', 'substitute', 'interchange',
  ],
  'notes': ['notes', 'note', 'comments', 'comment', 'remarks'],
};

/// A plain table: one part per row under headings such as "Part Number",
/// "Description", "Manufacturer", "Qty on hand".
List<ImportPart>? _parseFlat(SheetData sheet, List<SkippedEntry> skipped) {
  int? headRow;
  final cols = <String, int>{};
  for (var r = 0; r < sheet.rows.length && r < 12; r++) {
    final found = <String, int>{};
    for (var c = 0; c < sheet.rows[r].length; c++) {
      final h = cleanText(sheet.rows[r][c]).toLowerCase();
      if (h.isEmpty) continue;
      for (final e in _syn.entries) {
        if (found.containsKey(e.key)) continue;
        if (e.value.contains(h)) found[e.key] = c;
      }
    }
    if (found.containsKey('partNumber')) {
      headRow = r;
      cols.addAll(found);
      break;
    }
  }
  if (headRow == null) return null;

  String at(int r, String key) =>
      cols.containsKey(key) ? sheet.cell(r, cols[key]!) : '';

  int? whole(String raw, String label, ImportPart p) {
    final t = cleanText(raw).replaceAll(',', '');
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null) {
      p.warn('$label "$raw" is not a number — ignored');
      return null;
    }
    if (d < 0) {
      p.warn('$label is negative — ignored');
      return null;
    }
    if (d != d.roundToDouble()) {
      p.warn('$label $t rounded to ${d.round()}');
    }
    return d.round();
  }

  final parts = <ImportPart>[];
  for (var r = headRow + 1; r < sheet.rows.length; r++) {
    if (sheet.rows[r].every((c) => cleanText(c).isEmpty)) continue;
    final raw = at(r, 'partNumber');
    final slot = slotFromText(at(r, 'slot')) ??
        slotFromText(at(r, 'name'));
    final warnings = <String>[];
    final pn = cleanPartNumber(raw, slot: slot, warnings: warnings);
    if (pn.isEmpty) {
      skipped.add(SkippedEntry(
        sheet: sheet.name,
        row: r + 1,
        value: sheet.rows[r].map(cleanText).where((s) => s.isNotEmpty).join(' | '),
        reason: 'No part number',
      ));
      continue;
    }
    final mfrRaw = cleanText(at(r, 'manufacturer'));
    final p = ImportPart(
      partNumber: pn,
      name: cleanText(at(r, 'name')),
      manufacturer: isPlaceholder(mfrRaw)
          ? ''
          : (knownManufacturer(mfrRaw) ?? mfrRaw),
      slot: slot,
      notes: cleanText(at(r, 'notes')),
      sheets: [sheet.name],
    );
    for (final w in warnings) {
      p.warn(w);
    }
    p.minStock = whole(at(r, 'min'), 'Minimum', p) ?? 0;
    p.openingQty = whole(at(r, 'qty'), 'Quantity', p);
    final alts = at(r, 'alts');
    for (final a in alts.split(RegExp(r'[,;/\n]'))) {
      final c = cleanPartNumber(a, slot: slot);
      if (c.isNotEmpty && partKey(c) != partKey(pn)) p.alternates.add(c);
    }
    _sites[p] = 'Row ${r + 1}';
    parts.add(p);
  }
  return parts;
}

/// Folds repeats of the same part (same [partKey]) into one entry.
List<ImportPart> _merge(List<ImportPart> found) {
  final groups = <String, List<ImportPart>>{};
  for (final p in found) {
    groups.putIfAbsent(p.key, () => []).add(p);
  }
  final out = <ImportPart>[];
  for (final g in groups.values) {
    final first = g.first;
    final merged = ImportPart(partNumber: first.partNumber, sheets: []);

    String most(Iterable<String> values) {
      final counts = <String, int>{};
      for (final v in values.where((v) => v.isNotEmpty)) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      if (counts.isEmpty) return '';
      return (counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
    }

    final mfrs = g.map((p) => p.manufacturer).where((s) => s.isNotEmpty).toSet();
    merged.manufacturer = most(g.map((p) => p.manufacturer));
    if (mfrs.length > 1) {
      merged.warn('Listed under ${mfrs.length} manufacturers '
          '(${mfrs.join(', ')}) — kept ${merged.manufacturer}');
    }

    final slotCounts = <MaterialSlot, int>{};
    for (final p in g) {
      if (p.slot != null) slotCounts[p.slot!] = (slotCounts[p.slot!] ?? 0) + 1;
    }
    if (slotCounts.isNotEmpty) {
      final ranked = slotCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      merged.slot = ranked.first.key;
      if (ranked.length > 1) {
        merged.warn('Used in more than one slot '
            '(${ranked.map((e) => e.key.label).join(', ')}) — kept '
            '${merged.slot!.label}');
      }
    }

    merged.name = most(g.map((p) => p.name));
    merged.notes = most(g.map((p) => p.notes));
    merged.minStock = g.map((p) => p.minStock).fold(0, (a, b) => a > b ? a : b);
    // Counts for the same part listed twice add up.
    final qtys = g.map((p) => p.openingQty).whereType<int>();
    merged.openingQty = qtys.isEmpty ? null : qtys.fold<int>(0, (a, b) => a + b);

    final alts = <String>{};
    for (final p in g) {
      alts.addAll(p.alternates);
    }
    merged.alternates = alts.toList();

    final sites = <String>{
      for (final p in g) _sites[p] ?? '${identityHashCode(p)}',
    };
    merged.uses = sites.length;

    // Spellings that differ only by punctuation ("P-553000" and "P553000").
    final spellings = g.map((p) => p.partNumber).toSet();
    if (spellings.length > 1) {
      merged.warn('Written ${spellings.length} ways (${spellings.join(', ')}) '
          '— merged as ${merged.partNumber}');
    }

    for (final p in g) {
      merged.sheets.addAll(p.sheets.where((s) => !merged.sheets.contains(s)));
      for (final i in p.issues) {
        merged.warn(i.message);
      }
    }
    out.add(merged);
  }
  out.sort((a, b) => a.key.compareTo(b.key));
  return out;
}

// ---------------------------------------------------------------- planning

enum ImportAction {
  /// Not in the catalog: will be added.
  add,

  /// Already in the catalog and the sheet adds details to blank fields.
  fill,

  /// Already in the catalog with nothing new to add.
  same,
}

class PlannedPart {
  PlannedPart({required this.part, required this.action, this.existing, this.fills = const []});

  final ImportPart part;
  final ImportAction action;
  final CatalogPart? existing;

  /// Names of blank fields the import would fill on an existing part.
  final List<String> fills;
}

/// Compares what was read with the catalog already on the device. Existing
/// parts are never overwritten; only blank fields are filled.
List<PlannedPart> planImport(List<ImportPart> parts, List<CatalogPart> catalog) {
  final plan = <PlannedPart>[];
  for (final p in parts) {
    final match = findPartByNumber(catalog, p.partNumber);
    if (match == null) {
      plan.add(PlannedPart(part: p, action: ImportAction.add));
      continue;
    }
    final fills = <String>[
      if (match.manufacturer.isEmpty && p.manufacturer.isNotEmpty) 'manufacturer',
      if (match.slot == null && p.slot != null) 'slot',
      if (match.name.isEmpty && p.name.isNotEmpty) 'name',
      if (match.minStock == 0 && p.minStock > 0) 'minimum',
    ];
    plan.add(PlannedPart(
      part: p,
      action: fills.isEmpty ? ImportAction.same : ImportAction.fill,
      existing: match,
      fills: fills,
    ));
  }
  return plan;
}
