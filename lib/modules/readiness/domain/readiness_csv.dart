/// CSV export of the readiness list. Pure Dart.
library;

import 'readiness_models.dart';

const readinessCsvHeader = [
  'Unit',
  'Site code',
  'Address',
  'Customer',
  'Borough',
  'Make',
  'Model',
  'Serial',
  'Fuel',
  'Status',
  'Reasons',
  'Last inspection',
  'Last grade',
  'Next due',
  'Days to due',
  'Open follow-ups',
  'Follow-up notes',
  'Last load test',
  'Next load test due',
  'Next scheduled visit',
  'Parts short',
];

String _iso(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}

/// Quotes a text field. A leading `=`, `+`, `-`, `@` (or tab / CR) would be run
/// as a formula by spreadsheets, so such text gets a leading apostrophe.
String _text(String s) {
  var v = s;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  return '"${v.replaceAll('"', '""')}"';
}

/// A header row then one row per unit, every field quoted, rows ended with
/// CRLF, dates as `yyyy-MM-dd`. Line breaks inside notes stay inside their
/// quotes.
String readinessCsv(Iterable<ReadinessUnit> units) {
  final b = StringBuffer()
    ..write(readinessCsvHeader.map(_text).join(','))
    ..write('\r\n');
  for (final u in units) {
    final fields = <String>[
      _text(u.title),
      _text(u.siteCode),
      _text(u.address),
      _text(u.customer),
      _text(u.borough),
      _text(u.make),
      _text(u.model),
      _text(u.serial),
      _text(u.fuelType),
      _text(u.status.label),
      _text(u.reasons.map((r) => r.text).join('; ')),
      _text(_iso(u.lastInspectionAt)),
      _text(u.lastGrade == ReadinessGrade.none ? '' : u.lastGrade.label),
      _text(_iso(u.nextDueAt)),
      u.daysToDue?.toString() ?? '',
      u.followUpCount.toString(),
      _text(u.openFollowUps.map((f) => f.note).join('\n')),
      _text(_iso(u.lastLoadTestAt)),
      _text(_iso(u.nextLoadTestDueAt)),
      _text(_iso(u.scheduledTaskNext)),
      u.partsShortCount.toString(),
    ];
    b
      ..write(fields.join(','))
      ..write('\r\n');
  }
  return b.toString();
}
