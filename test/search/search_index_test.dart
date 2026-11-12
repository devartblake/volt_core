import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/search/domain/search_index.dart';

SearchEntry _e(
  SearchKind kind,
  String title, {
  String subtitle = '',
  String keywords = '',
  bool page = false,
}) =>
    SearchEntry(
      kind: kind,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      route: '/${title.toLowerCase().replaceAll(' ', '-')}',
      isPage: page,
    );

void main() {
  final entries = [
    _e(SearchKind.page, 'Inspections', page: true),
    _e(SearchKind.page, 'Schedule', page: true, keywords: 'Work'),
    _e(SearchKind.inspection, '244 East 168 Street, Bronx',
        subtitle: '10/30/2026  ·  X460  ·  Red', keywords: 'X460 Daniel'),
    _e(SearchKind.inspection, '63-60 80th Street, Queens',
        subtitle: '10/20/2026  ·  Q049  ·  Red', keywords: 'Q049'),
    _e(SearchKind.maintenance, '63-60 80 St, Queens', keywords: 'Q049'),
    _e(SearchKind.vehicle, 'Truck B', subtitle: 'ABC123  ·  Ford'),
    _e(SearchKind.customer, 'Acme Properties', subtitle: 'Pat  ·  555-0100'),
    _e(SearchKind.part, 'LF3000', subtitle: 'Oil filter  ·  Fleetguard', keywords: 'P551000'),
  ];

  List<String> titles(String q) =>
      searchEntries(entries, q).map((e) => e.title).toList();

  group('searchEntries', () {
    test('an empty or blank query finds nothing', () {
      expect(searchEntries(entries, ''), isEmpty);
      expect(searchEntries(entries, '   '), isEmpty);
    });

    test('matches the title, subtitle and hidden keywords', () {
      expect(titles('bronx'), ['244 East 168 Street, Bronx']);
      expect(titles('x460'), ['244 East 168 Street, Bronx']);
      expect(titles('daniel'), ['244 East 168 Street, Bronx']);
      expect(titles('ford'), ['Truck B']);
    });

    test('finds a part by number, name or alternate number', () {
      expect(titles('lf3000'), ['LF3000']);
      expect(titles('fleetguard'), ['LF3000']);
      expect(titles('p551000'), ['LF3000']);
      expect(groupByKind(searchEntries(entries, 'oil')).keys, contains(SearchKind.part));
    });

    test('is case-insensitive', () {
      expect(titles('TRUCK'), ['Truck B']);
    });

    test('every word must match, in any order', () {
      expect(titles('queens q049'), [
        '63-60 80th Street, Queens',
        '63-60 80 St, Queens',
      ]);
      expect(titles('queens bronx'), isEmpty);
    });

    test('a title that starts with the word outranks a looser match', () {
      final ranked = titles('sch');
      // The Schedule page starts with "sch"; nothing else even matches.
      expect(ranked.first, 'Schedule');
    });

    test('a page outranks a record for the same match', () {
      final both = [
        _e(SearchKind.inspection, 'Inspections for Acme'),
        _e(SearchKind.page, 'Inspections', page: true),
      ];
      expect(searchEntries(both, 'inspections').first.kind, SearchKind.page);
    });

    test('keeps source order for equal matches and honours the limit', () {
      final many = [
        for (var i = 0; i < 100; i++) _e(SearchKind.job, 'Job $i'),
      ];
      final out = searchEntries(many, 'job', limit: 10);
      expect(out.length, 10);
      expect(out.first.title, 'Job 0');
      expect(out.last.title, 'Job 9');
    });
  });

  group('groupByKind', () {
    test('groups in enum order and drops empty groups', () {
      final groups = groupByKind(searchEntries(entries, 'queens'));
      expect(groups.keys.toList(),
          [SearchKind.inspection, SearchKind.maintenance]);
      expect(groups[SearchKind.inspection]!.length, 1);
    });

    test('pages come before records', () {
      final groups = groupByKind(searchEntries(entries, 'in'));
      expect(groups.keys.first, SearchKind.page);
    });
  });

  group('equipment and schedule tasks', () {
    final more = [
      _e(SearchKind.equipment, 'Generac 22kW',
          subtitle: 'S/N 9X77  ·  X460', keywords: 'Generac RG022 9X77 Bronx'),
      _e(SearchKind.task, 'Quarterly service',
          subtitle: '11/3/2026  ·  scheduled', keywords: 'X460 Bronx'),
      _e(SearchKind.part, 'LF3000'),
    ];

    test('equipment matches serial, model and site', () {
      expect(searchEntries(more, '9x77').single.kind, SearchKind.equipment);
      expect(searchEntries(more, 'rg022').single.kind, SearchKind.equipment);
      expect(searchEntries(more, 'generac bronx').single.kind,
          SearchKind.equipment);
    });

    test('tasks match their site and group between equipment and parts', () {
      final groups = groupByKind(searchEntries(more, 'x460'));
      expect(groups.keys.toList(), [SearchKind.equipment, SearchKind.task]);
    });

    test('new kinds have labels and icons', () {
      expect(SearchKind.equipment.label, 'Equipment');
      expect(SearchKind.task.label, 'Schedule');
      expect(SearchKind.task.icon, isNotNull);
    });
  });
}
