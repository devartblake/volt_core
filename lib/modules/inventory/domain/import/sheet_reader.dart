import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// One worksheet as plain text cells. Row and column positions match the
/// spreadsheet (0-based); empty cells are ''.
class SheetData {
  const SheetData(this.name, this.rows);

  final String name;
  final List<List<String>> rows;

  int get width => rows.fold(0, (m, r) => r.length > m ? r.length : m);

  String cell(int row, int col) {
    if (row < 0 || row >= rows.length) return '';
    final r = rows[row];
    return col >= 0 && col < r.length ? r[col] : '';
  }
}

class SheetReadException implements Exception {
  const SheetReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads an .xlsx (or .csv) file into text cells. Formulas are read as the
/// value Excel last saved; dates come back as the serial number, which the
/// import never relies on.
List<SheetData> readSpreadsheet(Uint8List bytes, {String fileName = ''}) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.csv')) {
    return [SheetData('CSV', parseCsv(utf8.decode(bytes, allowMalformed: true)))];
  }
  try {
    return _readXlsx(bytes);
  } on SheetReadException {
    rethrow;
  } catch (_) {
    throw const SheetReadException(
        'That file could not be read. Use an .xlsx or .csv file.');
  }
}

int _colIndex(String ref) {
  var n = 0;
  for (final u in ref.codeUnits) {
    if (u >= 65 && u <= 90) {
      n = n * 26 + (u - 64);
    } else {
      break;
    }
  }
  return n - 1;
}

String _textOf(XmlElement e) =>
    e.findAllElements('t').map((t) => t.innerText).join();

List<SheetData> _readXlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? file(String path) {
    for (final f in zip) {
      if (f.name == path) return f;
    }
    return null;
  }

  String? read(String path) {
    final f = file(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final workbookXml = read('xl/workbook.xml');
  if (workbookXml == null) {
    throw const SheetReadException('That is not an Excel workbook.');
  }

  final shared = <String>[];
  final sstXml = read('xl/sharedStrings.xml');
  if (sstXml != null) {
    for (final si in XmlDocument.parse(sstXml).findAllElements('si')) {
      shared.add(_textOf(si));
    }
  }

  final rels = <String, String>{};
  final relsXml = read('xl/_rels/workbook.xml.rels');
  if (relsXml != null) {
    for (final r in XmlDocument.parse(relsXml).findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) rels[id] = target;
    }
  }

  final sheets = <SheetData>[];
  for (final s in XmlDocument.parse(workbookXml).findAllElements('sheet')) {
    if (s.getAttribute('state') == 'hidden') continue;
    final rid = s.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    var target = rid == null ? null : rels[rid];
    if (target == null) continue;
    target = target.startsWith('/')
        ? target.substring(1)
        : (target.startsWith('xl/') ? target : 'xl/$target');
    final xml = read(target);
    if (xml == null) continue;

    final rows = <List<String>>[];
    for (final row in XmlDocument.parse(xml).findAllElements('row')) {
      final r = (int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1) - 1;
      while (rows.length <= r) {
        rows.add(<String>[]);
      }
      final cells = rows[r];
      var next = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final idx = ref == null ? next : _colIndex(ref);
        next = idx + 1;
        final type = c.getAttribute('t');
        String val;
        if (type == 'inlineStr') {
          val = _textOf(c);
        } else {
          final v = c.getElement('v')?.innerText ?? '';
          if (type == 's') {
            final i = int.tryParse(v);
            val = i != null && i < shared.length ? shared[i] : '';
          } else if (type == 'b') {
            val = v == '1' ? 'TRUE' : 'FALSE';
          } else {
            val = v;
          }
        }
        while (cells.length <= idx) {
          cells.add('');
        }
        cells[idx] = val;
      }
    }
    sheets.add(SheetData(s.getAttribute('name') ?? 'Sheet', rows));
  }
  if (sheets.isEmpty) {
    throw const SheetReadException('That workbook has no sheets to read.');
  }
  return sheets;
}

/// Minimal RFC 4180 CSV reader: quoted fields, doubled quotes, CRLF.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  var i = 0;
  if (text.startsWith('﻿')) i = 1;
  void endField() {
    row.add(cur.toString());
    cur.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cur.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      endField();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      cur.write(ch);
    }
  }
  if (cur.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
