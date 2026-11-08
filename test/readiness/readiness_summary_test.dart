import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';

ReadinessUnit mk(
  String key, {
  ReadinessStatus status = ReadinessStatus.ready,
  int? days,
  DateTime? now,
  String title = '',
  String make = 'Kohler',
  String site = 'Q_1',
  String serial = '',
  String customer = '',
  String borough = 'Queens',
  ReadinessGrade grade = ReadinessGrade.green,
  int followUps = 0,
  int short = 0,
  DateTime? last,
}) {
  final base = now ?? DateTime(2026, 11, 7);
  return ReadinessUnit(
    key: key,
    title: title.isEmpty ? key : title,
    make: make,
    siteCode: site,
    serial: serial,
    customer: customer,
    borough: borough,
    lastGrade: grade,
    status: status,
    daysToDue: days,
    nextDueAt: days == null
        ? null
        : DateTime(base.year, base.month, base.day + days),
    lastInspectionAt: last,
    partsShortCount: short,
    openFollowUps: [
      for (var n = 0; n < followUps; n++)
        ReadinessFollowUp(sourceId: '$key$n', note: 'n$n'),
    ],
  );
}

void main() {
  // Saturday 7 Nov 2026: the week starts Monday 2 Nov.
  final now = DateTime(2026, 11, 7, 15);

  group('summary', () {
    test('no units: zeros, not 100 percent', () {
      final s = summarizeReadiness(const [], now);
      expect(s.total, 0);
      expect(s.percentReady, 0.0);
      expect(s.overdueCount, 0);
      expect(s.worstUnits, isEmpty);
      expect(s.dueByWeek, hasLength(12));
      expect(s.dueByWeek.every((b) => b.count == 0), isTrue);
      for (final st in ReadinessStatus.values) {
        expect(s.count(st), 0);
      }
    });

    test('counts, percent, grades, follow-ups and parts', () {
      final units = [
        mk('a', status: ReadinessStatus.ready, days: 100),
        mk('b', status: ReadinessStatus.ready, days: 100, grade: ReadinessGrade.amber),
        mk('c', status: ReadinessStatus.dueSoon, days: 5),
        mk('d',
            status: ReadinessStatus.attention,
            days: -3,
            followUps: 2,
            short: 1,
            grade: ReadinessGrade.none),
        mk('e', status: ReadinessStatus.notReady, days: -90, grade: ReadinessGrade.red),
        mk('f', status: ReadinessStatus.notReady, grade: ReadinessGrade.none),
      ];
      final s = summarizeReadiness(units, now);
      expect(s.total, 6);
      expect(s.count(ReadinessStatus.ready), 2);
      expect(s.count(ReadinessStatus.dueSoon), 1);
      expect(s.count(ReadinessStatus.attention), 1);
      expect(s.count(ReadinessStatus.notReady), 2);
      expect(s.percentReady, closeTo(33.33, 0.01));
      expect(s.overdueCount, 2);
      expect(s.dueSoonCount, 1);
      expect(s.gradeCounts[ReadinessGrade.green], 2);
      expect(s.gradeCounts[ReadinessGrade.amber], 1);
      expect(s.gradeCounts[ReadinessGrade.red], 1);
      expect(s.gradeCounts[ReadinessGrade.none], 2);
      expect(s.followUpCount, 2);
      expect(s.partsShortUnits, 1);
    });

    test('percentReady is 100 when all are ready', () {
      final s = summarizeReadiness([mk('a', days: 50), mk('b', days: 60)], now);
      expect(s.percentReady, 100.0);
    });

    test('worstUnits: worst status first, then most overdue, ready excluded', () {
      final units = [
        mk('ready', days: 100),
        mk('soon', status: ReadinessStatus.dueSoon, days: 2),
        mk('att', status: ReadinessStatus.attention, days: -5),
        mk('nr10', status: ReadinessStatus.notReady, days: -40),
        mk('nr90', status: ReadinessStatus.notReady, days: -90),
        mk('never', status: ReadinessStatus.notReady),
      ];
      final s = summarizeReadiness(units, now, worstCount: 4);
      expect(s.worstUnits.map((u) => u.key), ['nr90', 'nr10', 'never', 'att']);
    });
  });

  group('dueByWeek', () {
    int bucket(int days, {DateTime? at}) {
      final n = at ?? now;
      final s = summarizeReadiness([mk('x', days: days, now: n)], n);
      final i = s.dueByWeek.indexWhere((b) => b.count == 1);
      return i;
    }

    test('weeks start on Monday, the first is this week', () {
      final s = summarizeReadiness(const [], now);
      expect(s.dueByWeek.first.weekStart, DateTime(2026, 11, 2));
      expect(s.dueByWeek.every((b) => b.weekStart.weekday == DateTime.monday), isTrue);
      expect(s.dueByWeek[1].weekStart, DateTime(2026, 11, 9));
      expect(s.dueByWeek.last.weekStart, DateTime(2027, 1, 18));
    });

    test('today and Sunday are week 0, Monday is week 1', () {
      expect(bucket(0), 0); // Sat 7 Nov
      expect(bucket(1), 0); // Sun 8 Nov
      expect(bucket(2), 1); // Mon 9 Nov
      expect(bucket(8), 1); // Sun 15 Nov
      expect(bucket(9), 2); // Mon 16 Nov
    });

    test('last bucket edge and beyond', () {
      // Week 11 starts Mon 18 Jan 2027 = +72 days; ends Sun 24 Jan = +78.
      expect(bucket(72), 11);
      expect(bucket(78), 11);
      final s = summarizeReadiness([mk('x', days: 79)], now);
      expect(s.dueLater, 1);
      expect(s.dueByWeek.every((b) => b.count == 0), isTrue);
    });

    test('crosses the year boundary', () {
      // Mon 28 Dec 2026 week contains 31 Dec and 1 Jan.
      final s = summarizeReadiness([
        mk('a', days: 54), // Thu 31 Dec 2026
        mk('b', days: 55), // Fri 1 Jan 2027
        mk('c', days: 58), // Mon 4 Jan 2027
      ], now);
      final w = s.dueByWeek.indexWhere((b) => b.weekStart == DateTime(2026, 12, 28));
      expect(w, 8);
      expect(s.dueByWeek[w].count, 2);
      expect(s.dueByWeek[w + 1].weekStart, DateTime(2027, 1, 4));
      expect(s.dueByWeek[w + 1].count, 1);
    });

    test('overdue units are not in any bucket', () {
      final s = summarizeReadiness([mk('x', days: -1), mk('y', days: -50)], now);
      expect(s.overdueCount, 2);
      expect(s.dueByWeek.every((b) => b.count == 0), isTrue);
      expect(s.dueLater, 0);
    });

    test('a Monday "today" starts its own week; DST change does not shift', () {
      final mon = DateTime(2026, 11, 2, 8); // Monday
      expect(mondayOf(mon), DateTime(2026, 11, 2));
      expect(bucket(0, at: mon), 0);
      expect(bucket(6, at: mon), 0);
      expect(bucket(7, at: mon), 1);
      // The week of Sun 1 Nov 2026 (US clocks go back) still begins Mon 26 Oct.
      expect(mondayOf(DateTime(2026, 11, 1, 12)), DateTime(2026, 10, 26));
      final s = summarizeReadiness(const [], DateTime(2026, 10, 28));
      expect(s.dueByWeek[1].weekStart, DateTime(2026, 11, 2));
      expect(s.dueByWeek[2].weekStart, DateTime(2026, 11, 9));
    });

    test('a due date late on a day is in the same bucket as early', () {
      final u = ReadinessUnit(
        key: 'k',
        title: 'k',
        status: ReadinessStatus.ready,
        daysToDue: 1,
        nextDueAt: DateTime(2026, 11, 8, 23, 59),
      );
      expect(summarizeReadiness([u], now).dueByWeek.first.count, 1);
    });
  });

  group('filter', () {
    final units = [
      mk('a',
          title: 'Kohler 250REOZD',
          site: 'Q_001',
          serial: 'SN100',
          customer: 'City Hall',
          status: ReadinessStatus.ready,
          days: 100),
      mk('b',
          title: 'Generac G1',
          make: 'Generac',
          site: 'X_002',
          borough: 'Bronx',
          customer: 'Hospital',
          status: ReadinessStatus.attention,
          days: -4,
          followUps: 1,
          grade: ReadinessGrade.amber),
      mk('c',
          title: 'Cat C9',
          make: 'Cat',
          site: 'X_003',
          borough: 'Bronx',
          status: ReadinessStatus.dueSoon,
          days: 6,
          grade: ReadinessGrade.red),
      mk('d', title: 'Unknown', make: '', borough: '', status: ReadinessStatus.notReady),
    ];

    List<String> keys(ReadinessFilter f) => f.apply(units).map((u) => u.key).toList();

    test('empty filter keeps everything and says so', () {
      const f = ReadinessFilter();
      expect(f.isEmpty, isTrue);
      expect(keys(f), ['a', 'b', 'c', 'd']);
    });

    test('statuses', () {
      expect(
          keys(const ReadinessFilter(
              statuses: {ReadinessStatus.dueSoon, ReadinessStatus.notReady})),
          ['c', 'd']);
    });

    test('text query: all words, case-insensitive, across fields', () {
      expect(keys(const ReadinessFilter(query: 'kohler')), ['a']);
      expect(keys(const ReadinessFilter(query: 'q_001 city')), ['a']);
      expect(keys(const ReadinessFilter(query: 'sn100')), ['a']);
      expect(keys(const ReadinessFilter(query: 'HOSPITAL')), ['b']);
      expect(keys(const ReadinessFilter(query: 'x_00')), ['b', 'c']);
      expect(keys(const ReadinessFilter(query: 'kohler hospital')), isEmpty);
      expect(keys(const ReadinessFilter(query: '   ')), ['a', 'b', 'c', 'd']);
    });

    test('make and borough', () {
      expect(keys(const ReadinessFilter(make: 'generac')), ['b']);
      expect(keys(const ReadinessFilter(borough: 'Bronx')), ['b', 'c']);
    });

    test('due window', () {
      expect(keys(const ReadinessFilter(dueWindow: ReadinessDueWindow.overdue)), ['b']);
      expect(keys(const ReadinessFilter(dueWindow: ReadinessDueWindow.next7)), ['c']);
      expect(keys(const ReadinessFilter(dueWindow: ReadinessDueWindow.next30)), ['c']);
      expect(keys(const ReadinessFilter(dueWindow: ReadinessDueWindow.next90)), ['c']);
    });

    test('due window edges', () {
      expect(ReadinessDueWindow.next7.matches(7), isTrue);
      expect(ReadinessDueWindow.next7.matches(8), isFalse);
      expect(ReadinessDueWindow.next7.matches(0), isTrue);
      expect(ReadinessDueWindow.next7.matches(-1), isFalse);
      expect(ReadinessDueWindow.next30.matches(30), isTrue);
      expect(ReadinessDueWindow.next90.matches(91), isFalse);
      expect(ReadinessDueWindow.overdue.matches(0), isFalse);
      expect(ReadinessDueWindow.overdue.matches(null), isFalse);
    });

    test('follow-ups and grade', () {
      expect(keys(const ReadinessFilter(hasFollowUps: true)), ['b']);
      expect(keys(const ReadinessFilter(hasFollowUps: false)), ['a', 'c', 'd']);
      expect(keys(const ReadinessFilter(grade: ReadinessGrade.red)), ['c']);
    });

    test('conditions combine with AND', () {
      expect(
          keys(const ReadinessFilter(borough: 'Bronx', grade: ReadinessGrade.amber)),
          ['b']);
    });

    test('copyWith can set and clear', () {
      final f = const ReadinessFilter()
          .copyWith(make: 'Cat', grade: ReadinessGrade.red)
          .copyWith(clearMake: true);
      expect(f.make, isNull);
      expect(f.grade, ReadinessGrade.red);
      expect(f.copyWith(clearGrade: true).isEmpty, isTrue);
    });

    test('equality is by value', () {
      expect(
          const ReadinessFilter(statuses: {ReadinessStatus.ready}, query: 'a'),
          const ReadinessFilter(statuses: {ReadinessStatus.ready}, query: 'a'));
      expect(const ReadinessFilter(query: 'a') == const ReadinessFilter(query: 'b'),
          isFalse);
    });

    test('distinct makes and boroughs', () {
      expect(distinctMakes(units), ['Cat', 'Generac', 'Kohler']);
      expect(distinctBoroughs(units), ['Bronx', 'Queens']);
    });
  });

  group('sort', () {
    final t = DateTime(2026, 1, 1);
    final units = [
      mk('b', title: 'beta', days: 10, last: t.add(const Duration(days: 5))),
      mk('a', title: 'Alpha', days: 10, last: t.add(const Duration(days: 1))),
      mk('c', title: 'gamma', days: -2, last: t),
      mk('n1', title: 'nodate1', days: null),
      mk('n2', title: 'nodate0', days: null),
    ];

    List<String> keys(ReadinessSort s) =>
        sortReadiness(units, s).map((u) => u.key).toList();

    test('title is case-insensitive', () {
      expect(keys(ReadinessSort.title), ['a', 'b', 'c', 'n2', 'n1']);
    });

    test('nextDue: earliest first, ties by title, no date last', () {
      expect(keys(ReadinessSort.nextDue), ['c', 'a', 'b', 'n2', 'n1']);
    });

    test('lastInspection: oldest first, never inspected at the top', () {
      expect(keys(ReadinessSort.lastInspection), ['n2', 'n1', 'c', 'a', 'b']);
    });

    test('worstFirst is a total order independent of input order', () {
      final shuffled = [...units]..shuffle();
      expect(sortReadiness(shuffled, ReadinessSort.worstFirst).map((u) => u.key),
          sortReadiness(units.reversed, ReadinessSort.worstFirst).map((u) => u.key));
    });

    test('ties with equal titles fall back to key', () {
      final twins = [mk('z', title: 'same', days: 1), mk('y', title: 'same', days: 1)];
      for (final s in ReadinessSort.values) {
        expect(sortReadiness(twins, s).map((u) => u.key), ['y', 'z'], reason: s.name);
      }
    });

    test('does not change the input list', () {
      final copy = List.of(units);
      sortReadiness(units, ReadinessSort.title);
      expect(units.map((u) => u.key), copy.map((u) => u.key));
    });
  });
}
