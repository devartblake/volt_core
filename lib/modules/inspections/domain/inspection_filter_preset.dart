import 'dart:convert';

import '../presenter/inspection_date_filter.dart';
import 'entities/inspection_entity.dart';

/// Everything the inspections list can be narrowed by: dates, site grade
/// (the inspection "status": Green / Amber / Red) and free text.
///
/// Pure value logic with no widgets, so it can be saved, restored and tested
/// directly. There is no trade/type field on an inspection today, so there is
/// no trade filter.
class InspectionListFilter {
  const InspectionListFilter({
    this.date = const InspectionDateFilter.all(),
    this.grades = const {},
    this.query = '',
  });

  final InspectionDateFilter date;

  /// Lower-case grades to keep ("green", "amber", "red"). Empty means all.
  final Set<String> grades;

  /// Case-insensitive text matched against title, site code, technician and
  /// customer. Empty means no text filter.
  final String query;

  /// True when nothing narrows the list.
  bool get isDefault => date.isAll && grades.isEmpty && query.trim().isEmpty;

  InspectionListFilter copyWith({
    InspectionDateFilter? date,
    Set<String>? grades,
    String? query,
  }) =>
      InspectionListFilter(
        date: date ?? this.date,
        grades: grades ?? this.grades,
        query: query ?? this.query,
      );

  /// Whether [i] passes the grade and text parts (not the date part, which
  /// also sorts; see [apply]).
  bool matchesNonDate(InspectionEntity i) {
    if (grades.isNotEmpty && !grades.contains(i.siteGrade.toLowerCase())) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      i.displayTitle,
      i.siteCode,
      i.technicianName,
      i.customerName,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }

  /// Narrow [items] to this filter, newest first.
  List<InspectionEntity> apply(Iterable<InspectionEntity> items) =>
      date.apply(items.where(matchesNonDate));
}

/// A named, saved [InspectionListFilter].
///
/// A date range saved while it contained today is stored as [rolling]: it
/// follows the calendar ("This week" is always the current week). Otherwise
/// the exact [anchor] day is kept.
class InspectionFilterPreset {
  const InspectionFilterPreset({
    required this.id,
    required this.name,
    this.period = InspectionPeriod.all,
    this.anchor,
    this.rolling = true,
    this.grades = const {},
    this.query = '',
    this.builtIn = false,
  });

  final String id;
  final String name;
  final InspectionPeriod period;
  final DateTime? anchor;
  final bool rolling;
  final Set<String> grades;
  final String query;

  /// Built-ins are shipped with the app: never stored, renamed or deleted.
  final bool builtIn;

  /// Captures [filter] under [name]. [today] defaults to now.
  factory InspectionFilterPreset.fromFilter({
    required String id,
    required String name,
    required InspectionListFilter filter,
    DateTime? today,
  }) {
    final date = filter.date;
    return InspectionFilterPreset(
      id: id,
      name: name,
      period: date.period,
      anchor: date.anchor,
      rolling: date.isAll || date.containsToday(today ?? DateTime.now()),
      grades: Set.of(filter.grades),
      query: filter.query.trim(),
    );
  }

  /// The filter this preset stands for, as of [today].
  InspectionListFilter toFilter({DateTime? today}) {
    final InspectionDateFilter date;
    if (period == InspectionPeriod.all) {
      date = const InspectionDateFilter.all();
    } else {
      date = InspectionDateFilter.of(
        period,
        rolling ? (today ?? DateTime.now()) : (anchor ?? DateTime.now()),
      );
    }
    return InspectionListFilter(date: date, grades: grades, query: query);
  }

  /// Whether [filter] is exactly what applying this preset gives.
  bool matches(InspectionListFilter filter, {DateTime? today}) {
    final mine = toFilter(today: today);
    return mine.date.period == filter.date.period &&
        mine.date.start == filter.date.start &&
        mine.grades.length == filter.grades.length &&
        mine.grades.containsAll(filter.grades) &&
        mine.query.trim().toLowerCase() == filter.query.trim().toLowerCase();
  }

  InspectionFilterPreset copyWith({String? name}) => InspectionFilterPreset(
        id: id,
        name: name ?? this.name,
        period: period,
        anchor: anchor,
        rolling: rolling,
        grades: grades,
        query: query,
        builtIn: builtIn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'period': period.name,
        if (anchor != null) 'anchor': anchor!.toIso8601String(),
        'rolling': rolling,
        'grades': grades.toList()..sort(),
        'query': query,
      };

  /// Null when [json] is not a usable preset (missing id or name).
  static InspectionFilterPreset? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      return null;
    }
    final period = InspectionPeriod.values.firstWhere(
      (p) => p.name == json['period'],
      orElse: () => InspectionPeriod.all,
    );
    final rawAnchor = json['anchor'];
    final rawGrades = json['grades'];
    return InspectionFilterPreset(
      id: id,
      name: name.trim(),
      period: period,
      anchor: rawAnchor is String ? DateTime.tryParse(rawAnchor) : null,
      rolling: json['rolling'] is bool ? json['rolling'] as bool : true,
      grades: rawGrades is List
          ? rawGrades.whereType<String>().map((g) => g.toLowerCase()).toSet()
          : const {},
      query: json['query'] is String ? json['query'] as String : '',
    );
  }

  /// Shipped presets. Only ones the data supports: dates and grade.
  static const List<InspectionFilterPreset> builtIns = [
    InspectionFilterPreset(
      id: 'builtin-this-week',
      name: 'This week',
      period: InspectionPeriod.week,
      builtIn: true,
    ),
    InspectionFilterPreset(
      id: 'builtin-needs-follow-up',
      name: 'Needs follow-up',
      grades: {'amber', 'red'},
      builtIn: true,
    ),
  ];
}

/// Saved presets <-> the JSON string kept in preferences.
class InspectionFilterPresetCodec {
  const InspectionFilterPresetCodec._();

  static String encode(List<InspectionFilterPreset> presets) => jsonEncode([
        for (final p in presets)
          if (!p.builtIn) p.toJson(),
      ]);

  /// Tolerant: bad JSON or bad entries give an empty / shorter list, never an
  /// exception, so a corrupt preference cannot break the list page.
  static List<InspectionFilterPreset> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (InspectionFilterPreset.tryFromJson(e) case final p?) p,
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// List row density.
enum InspectionDensity {
  comfortable,
  compact;

  static InspectionDensity parse(String? raw) => InspectionDensity.values
      .firstWhere((d) => d.name == raw, orElse: () => comfortable);
}
