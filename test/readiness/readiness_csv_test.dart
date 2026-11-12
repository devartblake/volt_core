import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_csv.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';

/// Minimal RFC 4180 reader so the tests check what a spreadsheet would see.
List<List<String>> parse(String csv) {
  final rows = <List<String>>[];
  var row = <String>[];
  final f = StringBuffer();
  var inQ = false;
  for (var i = 0; i < csv.length; i++) {
    final c = csv[i];
    if (inQ) {
      if (c == '"') {
        if (i + 1 < csv.length && csv[i + 1] == '"') {
          f.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        f.write(c);
      }
    } else if (c == '"') {
      inQ = true;
    } else if (c == ',') {
      row.add(f.toString());
      f.clear();
    } else if (c == '\r') {
      // swallow, \n ends the row
    } else if (c == '\n') {
      row.add(f.toString());
      f.clear();
      rows.add(row);
      row = <String>[];
    } else {
      f.write(c);
    }
  }
  return rows;
}

void main() {
  test('header only for an empty list', () {
    final rows = parse(readinessCsv(const []));
    expect(rows, hasLength(1));
    expect(rows.single, readinessCsvHeader);
  });

  test('one row per unit with ISO dates and plain numbers', () {
    final u = ReadinessUnit(
      key: 'k',
      title: 'Kohler 250REOZD',
      siteCode: 'Q_001',
      address: '1 Main St, Queens',
      customer: 'City Hall',
      borough: 'Queens',
      make: 'Kohler',
      model: '250REOZD',
      serial: 'SN1',
      fuelType: 'Diesel',
      lastInspectionAt: DateTime(2026, 10, 3, 14, 30),
      lastGrade: ReadinessGrade.amber,
      nextDueAt: DateTime(2026, 11, 20),
      daysToDue: 13,
      openFollowUps: const [ReadinessFollowUp(sourceId: 'm', note: 'Belt')],
      lastLoadTestAt: DateTime(2026, 1, 5),
      nextLoadTestDueAt: DateTime(2027, 1, 5),
      scheduledTaskNext: DateTime(2026, 11, 12, 9),
      partsShortCount: 2,
      status: ReadinessStatus.attention,
      reasons: const [
        ReadinessReason(ReadinessReasonKind.amberGrade, ReadinessSeverity.warning,
            'Last inspection was Amber (3 Oct)'),
        ReadinessReason(
            ReadinessReasonKind.dueSoon, ReadinessSeverity.info, 'Due in 13 days'),
      ],
    );
    final rows = parse(readinessCsv([u]));
    expect(rows, hasLength(2));
    final r = Map.fromIterables(rows[0], rows[1]);
    expect(r['Unit'], 'Kohler 250REOZD');
    expect(r['Address'], '1 Main St, Queens');
    expect(r['Status'], 'Needs attention');
    expect(r['Reasons'], 'Last inspection was Amber (3 Oct); Due in 13 days');
    expect(r['Last inspection'], '2026-10-03');
    expect(r['Last grade'], 'Amber');
    expect(r['Next due'], '2026-11-20');
    expect(r['Days to due'], '13');
    expect(r['Open follow-ups'], '1');
    expect(r['Last load test'], '2026-01-05');
    expect(r['Next load test due'], '2027-01-05');
    expect(r['Next scheduled visit'], '2026-11-12');
    expect(r['Parts short'], '2');
    expect(readinessCsv([u]).split('\r\n').length, 3, reason: 'CRLF rows + trailing');
  });

  test('every text field is quoted; numbers and blanks are not', () {
    const u = ReadinessUnit(key: 'k', title: 'T', status: ReadinessStatus.ready);
    final line = readinessCsv([u]).split('\r\n')[1];
    expect(line.startsWith('"T",'), isTrue);
    expect(line.endsWith(',"",0'), isTrue, reason: line);
  });

  test('quotes, commas and newlines survive a round trip', () {
    const u = ReadinessUnit(
      key: 'k',
      title: 'He said "go", then left',
      address: 'Line one\nLine two',
      status: ReadinessStatus.ready,
      openFollowUps: [
        ReadinessFollowUp(sourceId: 'a', note: 'Replace "belt", now'),
        ReadinessFollowUp(sourceId: 'b', note: 'Check\r\nhoses'),
      ],
    );
    final rows = parse(readinessCsv([u, u]));
    expect(rows, hasLength(3));
    final r = Map.fromIterables(rows[0], rows[1]);
    expect(r['Unit'], 'He said "go", then left');
    expect(r['Address'], 'Line one\nLine two');
    expect(r['Follow-up notes'], 'Replace "belt", now\nCheck\r\nhoses');
    expect(rows[1].length, readinessCsvHeader.length);
    expect(rows[2], rows[1]);
  });

  test('text that a spreadsheet would run as a formula is defused', () {
    const u = ReadinessUnit(
        key: 'k', title: '=HYPERLINK("x")', customer: '+1 Co', status: ReadinessStatus.ready);
    final rows = parse(readinessCsv([u]));
    final r = Map.fromIterables(rows[0], rows[1]);
    expect(r['Unit'], '\'=HYPERLINK("x")');
    expect(r['Customer'], "'+1 Co");
  });

  test('negative days are a number, not text', () {
    const u = ReadinessUnit(
        key: 'k', title: 'T', status: ReadinessStatus.notReady, daysToDue: -12);
    final rows = parse(readinessCsv([u]));
    expect(Map.fromIterables(rows[0], rows[1])['Days to due'], '-12');
  });

  test('never inspected leaves date and grade cells empty', () {
    const u = ReadinessUnit(key: 'k', title: 'T', status: ReadinessStatus.notReady);
    final r = Map.fromIterables(
        parse(readinessCsv([u]))[0], parse(readinessCsv([u]))[1]);
    expect(r['Last inspection'], '');
    expect(r['Last grade'], '');
    expect(r['Next due'], '');
    expect(r['Days to due'], '');
  });
}
