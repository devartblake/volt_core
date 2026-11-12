import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/presenter/inspection_date_filter.dart';

InspectionEntity _on(DateTime day, {String site = 'S'}) =>
    InspectionEntity.newDraft().copyWith(serviceDate: day, siteCode: site);

void main() {
  group('week (Monday to Sunday)', () {
    // Wed 4 Nov 2026
    final f = InspectionDateFilter.of(
        InspectionPeriod.week, DateTime(2026, 11, 4, 15, 30));

    test('runs Monday 2 Nov to Sunday 8 Nov', () {
      expect(f.start, DateTime(2026, 11, 2));
      expect(f.end, DateTime(2026, 11, 8));
    });

    test('includes both ends and ignores the time of day', () {
      expect(f.matches(DateTime(2026, 11, 2, 0, 0)), isTrue);
      expect(f.matches(DateTime(2026, 11, 8, 23, 59)), isTrue);
    });

    test('excludes the day before and after', () {
      expect(f.matches(DateTime(2026, 11, 1)), isFalse);
      expect(f.matches(DateTime(2026, 11, 9)), isFalse);
    });

    test('a Sunday belongs to the week that ends on it', () {
      final sunday = InspectionDateFilter.of(
          InspectionPeriod.week, DateTime(2026, 11, 8));
      expect(sunday.start, DateTime(2026, 11, 2));
    });

    test('stepping moves whole weeks, across a month and a year', () {
      expect(f.shifted(-1).start, DateTime(2026, 10, 26));
      final newYear = InspectionDateFilter.of(
          InspectionPeriod.week, DateTime(2026, 12, 30));
      expect(newYear.shifted(1).start, DateTime(2027, 1, 4));
    });

    test('label names the span, including across months', () {
      expect(f.label, 'Nov 2 - 8, 2026');
      expect(f.shifted(-1).label, 'Oct 26 - Nov 1, 2026');
    });
  });

  group('month', () {
    test('February in a leap and a non-leap year', () {
      expect(
        InspectionDateFilter.of(InspectionPeriod.month, DateTime(2028, 2, 10))
            .end,
        DateTime(2028, 2, 29),
      );
      expect(
        InspectionDateFilter.of(InspectionPeriod.month, DateTime(2027, 2, 10))
            .end,
        DateTime(2027, 2, 28),
      );
    });

    test('stepping back from January lands in December of the year before', () {
      final jan = InspectionDateFilter.of(
          InspectionPeriod.month, DateTime(2027, 1, 20));
      final prev = jan.shifted(-1);
      expect(prev.start, DateTime(2026, 12, 1));
      expect(prev.label, 'December 2026');
    });

    test('31 January steps to February without skipping a month', () {
      final jan31 = InspectionDateFilter.of(
          InspectionPeriod.month, DateTime(2026, 1, 31));
      expect(jan31.shifted(1).start, DateTime(2026, 2, 1));
    });
  });

  group('single day', () {
    final f = InspectionDateFilter.of(InspectionPeriod.day, DateTime(2026, 11, 3));

    test('matches only that day', () {
      expect(f.matches(DateTime(2026, 11, 3, 18)), isTrue);
      expect(f.matches(DateTime(2026, 11, 4)), isFalse);
    });

    test('label reads like a date', () {
      expect(f.label, 'Tue, Nov 3, 2026');
    });

    test('stepping moves by one day', () {
      expect(f.shifted(1).start, DateTime(2026, 11, 4));
    });
  });

  test('all matches everything and has no range', () {
    const f = InspectionDateFilter.all();
    expect(f.isAll, isTrue);
    expect(f.matches(DateTime(1999, 1, 1)), isTrue);
    expect(f.start, isNull);
    expect(f.label, 'All dates');
    expect(f.shifted(1).isAll, isTrue);
  });

  test('switching period keeps the anchor date', () {
    final day = InspectionDateFilter.of(InspectionPeriod.day, DateTime(2026, 11, 4));
    expect(day.withPeriod(InspectionPeriod.week).start, DateTime(2026, 11, 2));
    expect(day.withPeriod(InspectionPeriod.month).start, DateTime(2026, 11, 1));
  });

  group('apply and group', () {
    final items = [
      _on(DateTime(2026, 10, 30), site: 'old'),
      _on(DateTime(2026, 11, 3), site: 'tue-a'),
      _on(DateTime(2026, 11, 3), site: 'tue-b'),
      _on(DateTime(2026, 11, 5), site: 'thu'),
      _on(DateTime(2026, 11, 20), site: 'later'),
    ];

    test('apply narrows to the period and sorts newest first', () {
      final week = InspectionDateFilter.of(
          InspectionPeriod.week, DateTime(2026, 11, 4));
      final out = week.apply(items);
      expect(out.map((i) => i.siteCode).toList().last, anyOf('tue-a', 'tue-b'));
      expect(out.first.siteCode, 'thu');
      expect(out.length, 3);
    });

    test('a week or month groups by day, newest day first', () {
      final month = InspectionDateFilter.of(
          InspectionPeriod.month, DateTime(2026, 11, 1));
      final groups = month.group(month.apply(items));
      expect(groups.map((g) => g.title).toList(),
          ['Fri, Nov 20', 'Thu, Nov 5', 'Tue, Nov 3']);
      expect(groups.last.items.length, 2);
    });

    test('all groups by day too, with the year in each heading', () {
      const all = InspectionDateFilter.all();
      final groups = all.group(all.apply(items));
      expect(groups.map((g) => g.title).toList(), [
        'Fri, Nov 20, 2026',
        'Thu, Nov 5, 2026',
        'Tue, Nov 3, 2026',
        'Fri, Oct 30, 2026',
      ]);
    });

    test('an empty period yields no groups', () {
      final empty = InspectionDateFilter.of(
          InspectionPeriod.day, DateTime(2030, 1, 1));
      expect(empty.group(empty.apply(items)), isEmpty);
    });
  });
}
