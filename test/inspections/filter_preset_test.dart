import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_filter_preset.dart';
import 'package:voltcore/modules/inspections/presenter/inspection_date_filter.dart';

InspectionEntity _ins(String site, String grade, DateTime day,
        {String address = ''}) =>
    InspectionEntity.newDraft().copyWith(
        siteCode: site, siteGrade: grade, serviceDate: day, address: address);

void main() {
  final today = DateTime(2026, 11, 4); // Wednesday
  final items = [
    _ins('A1', 'Green', DateTime(2026, 11, 3), address: '10 Main St'),
    _ins('B2', 'Amber', DateTime(2026, 11, 4), address: '22 Oak Ave'),
    _ins('C3', 'Red', DateTime(2026, 10, 1), address: '5 Pine Rd'),
  ];

  group('InspectionListFilter', () {
    test('default keeps everything, newest first', () {
      const f = InspectionListFilter();
      expect(f.isDefault, isTrue);
      expect(f.apply(items).map((i) => i.siteCode), ['B2', 'A1', 'C3']);
    });

    test('grades are case-insensitive and combine with dates', () {
      final f = InspectionListFilter(
        date: InspectionDateFilter.of(InspectionPeriod.week, today),
        grades: const {'amber', 'red'},
      );
      expect(f.apply(items).map((i) => i.siteCode), ['B2']);
    });

    test('text matches address / site words, any order', () {
      expect(
          const InspectionListFilter(query: 'oak 22')
              .apply(items)
              .map((i) => i.siteCode),
          ['B2']);
      expect(
          const InspectionListFilter(query: 'c3')
              .apply(items)
              .map((i) => i.siteCode),
          ['C3']);
      expect(const InspectionListFilter(query: 'zzz').apply(items), isEmpty);
    });
  });

  group('presets', () {
    test('a week saved while it contains today rolls with the calendar', () {
      final saved = InspectionFilterPreset.fromFilter(
        id: '1',
        name: 'Week',
        filter: InspectionListFilter(
            date: InspectionDateFilter.of(InspectionPeriod.week, today)),
        today: today,
      );
      expect(saved.rolling, isTrue);
      final nextWeek = DateTime(2026, 11, 11);
      expect(
          saved.toFilter(today: nextWeek).date.start, DateTime(2026, 11, 9));
    });

    test('a past month keeps its exact anchor', () {
      final saved = InspectionFilterPreset.fromFilter(
        id: '1',
        name: 'Oct',
        filter: InspectionListFilter(
            date: InspectionDateFilter.of(
                InspectionPeriod.month, DateTime(2026, 10, 15))),
        today: today,
      );
      expect(saved.rolling, isFalse);
      expect(saved.toFilter(today: today).date.start, DateTime(2026, 10, 1));
    });

    test('matches reports whether a filter equals the preset', () {
      final p = InspectionFilterPreset.builtIns.last; // needs follow-up
      expect(p.matches(p.toFilter()), isTrue);
      expect(p.matches(const InspectionListFilter(grades: {'red'})), isFalse);
      expect(p.toFilter().apply(items).map((i) => i.siteCode), ['B2', 'C3']);
    });

    test('JSON round trip keeps everything and drops built-ins', () {
      final saved = InspectionFilterPreset.fromFilter(
        id: 'x',
        name: 'Red this month',
        filter: InspectionListFilter(
          date: InspectionDateFilter.of(InspectionPeriod.month, today),
          grades: const {'red'},
          query: ' pine ',
        ),
        today: today,
      );
      final json = InspectionFilterPresetCodec.encode(
          [...InspectionFilterPreset.builtIns, saved]);
      final back = InspectionFilterPresetCodec.decode(json);
      expect(back, hasLength(1));
      expect(back.single.name, 'Red this month');
      expect(back.single.period, InspectionPeriod.month);
      expect(back.single.grades, {'red'});
      expect(back.single.query, 'pine');
      expect(back.single.rolling, isTrue);
    });

    test('corrupt input never throws', () {
      expect(InspectionFilterPresetCodec.decode(null), isEmpty);
      expect(InspectionFilterPresetCodec.decode('not json'), isEmpty);
      expect(InspectionFilterPresetCodec.decode('{"a":1}'), isEmpty);
      final partly = InspectionFilterPresetCodec.decode(
          '[{"id":"1","name":"ok","period":"bogus"},{"name":""},3]');
      expect(partly.single.period, InspectionPeriod.all);
    });
  });

  test('density parses with a safe default', () {
    expect(InspectionDensity.parse('compact'), InspectionDensity.compact);
    expect(InspectionDensity.parse('x'), InspectionDensity.comfortable);
    expect(InspectionDensity.parse(null), InspectionDensity.comfortable);
  });
}
