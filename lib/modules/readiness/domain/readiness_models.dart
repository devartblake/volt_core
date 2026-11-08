/// Value types for the Fleet readiness layer. Pure Dart: no Flutter, no Hive.
///
/// See docs/fleet_readiness.md for the data sources, join rules and the rules
/// table. The rules themselves live in `readiness_rules.dart`.
library;

/// How ready a generator is to run when needed. Declared worst first, so
/// [rank] 0 is the worst.
enum ReadinessStatus {
  notReady('Not ready'),
  attention('Needs attention'),
  dueSoon('Due soon'),
  ready('Ready');

  const ReadinessStatus(this.label);

  final String label;

  /// 0 = worst ([notReady]) ... 3 = best ([ready]).
  int get rank => index;
}

/// How serious one [ReadinessReason] is.
enum ReadinessSeverity { info, warning, critical }

/// What kind of finding a [ReadinessReason] is, so a screen can pick an icon
/// without parsing [ReadinessReason.text].
enum ReadinessReasonKind {
  neverInspected,
  redGrade,
  amberGrade,
  overdue,
  dueSoon,
  estimatedDueDate,
  followUps,
  partsShort,
  visitScheduled,
  visitMissed,
}

/// One plain-language finding behind a unit's status.
class ReadinessReason {
  const ReadinessReason(this.kind, this.severity, this.text);

  final ReadinessReasonKind kind;
  final ReadinessSeverity severity;
  final String text;

  @override
  String toString() => '${severity.name}: $text';
}

/// Site grade of an inspection.
enum ReadinessGrade {
  green('Green'),
  amber('Amber'),
  red('Red'),
  none('Ungraded');

  const ReadinessGrade(this.label);

  final String label;

  /// Case-insensitive; anything unrecognised (including '') is [none].
  static ReadinessGrade parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'green':
        return green;
      case 'amber':
        return amber;
      case 'red':
        return red;
    }
    return none;
  }
}

/// The threshold settings. Defaults match the documented
/// rules table.
class ReadinessConfig {
  const ReadinessConfig({
    this.dueSoonDays = 30,
    this.criticalOverdueDays = 30,
    this.staleInspectionDays = 365,
    this.loadTestIntervalDays = 365,
  });

  /// A unit due within this many days (0 = today) is "due soon".
  final int dueSoonDays;

  /// Overdue by up to and including this many days is "needs attention";
  /// more than this is "not ready".
  final int criticalOverdueDays;

  /// For a unit whose latest inspection has no next-due date: the date is
  /// assumed to be this many days after that inspection.
  final int staleInspectionDays;

  /// Informational only: next load test = last load test + this.
  final int loadTestIntervalDays;

  ReadinessConfig copyWith({
    int? dueSoonDays,
    int? criticalOverdueDays,
    int? staleInspectionDays,
    int? loadTestIntervalDays,
  }) =>
      ReadinessConfig(
        dueSoonDays: dueSoonDays ?? this.dueSoonDays,
        criticalOverdueDays: criticalOverdueDays ?? this.criticalOverdueDays,
        staleInspectionDays: staleInspectionDays ?? this.staleInspectionDays,
        loadTestIntervalDays: loadTestIntervalDays ?? this.loadTestIntervalDays,
      );

  @override
  bool operator ==(Object other) =>
      other is ReadinessConfig &&
      other.dueSoonDays == dueSoonDays &&
      other.criticalOverdueDays == criticalOverdueDays &&
      other.staleInspectionDays == staleInspectionDays &&
      other.loadTestIntervalDays == loadTestIntervalDays;

  @override
  int get hashCode => Object.hash(
      dueSoonDays, criticalOverdueDays, staleInspectionDays, loadTestIntervalDays);
}

/// An open follow-up on a unit (from a maintenance record that asked for one).
class ReadinessFollowUp {
  const ReadinessFollowUp({
    required this.sourceId,
    required this.note,
    this.date,
  });

  /// The maintenance record id.
  final String sourceId;

  /// Short text (trimmed, clipped to 80 characters).
  final String note;
  final DateTime? date;
}

/// One generator (or, when nothing identifies it better, one site) and where
/// it stands. Built only by `computeReadiness`.
class ReadinessUnit {
  const ReadinessUnit({
    required this.key,
    required this.title,
    this.profileKey = '',
    this.siteCode = '',
    this.address = '',
    this.customer = '',
    this.borough = '',
    this.make = '',
    this.model = '',
    this.serial = '',
    this.fuelType = '',
    this.lastInspectionAt,
    this.lastGrade = ReadinessGrade.none,
    this.lastGradeAt,
    this.nextDueAt,
    this.dueIsEstimated = false,
    this.daysToDue,
    this.openFollowUps = const [],
    this.lastLoadTestAt,
    this.nextLoadTestDueAt,
    this.scheduledTaskNext,
    this.partsShortCount = 0,
    required this.status,
    this.reasons = const [],
    this.latestInspectionId,
  });

  /// Stable identity: the parts-profile key when a serial is known, else
  /// `site:<code>`, else `id:<id>`.
  final String key;

  /// "Kohler 250REOZD", else the site code or address, else "Unknown unit".
  final String title;

  /// `generatorProfileKey(make, model, serial)` or '' - the key to open this
  /// unit's parts profile with.
  final String profileKey;
  final String siteCode;
  final String address;

  /// Customer name from the customer/site directory, '' if unknown.
  final String customer;

  /// "Queens" / "Bronx" when the site code starts with `Q_` / `X_`, else ''.
  final String borough;
  final String make;
  final String model;
  final String serial;
  final String fuelType;

  /// Null when never inspected.
  final DateTime? lastInspectionAt;
  final ReadinessGrade lastGrade;

  /// Date of the inspection that [lastGrade] came from.
  final DateTime? lastGradeAt;

  /// The date the next inspection is due; when [dueIsEstimated] it is the last
  /// inspection plus `staleInspectionDays`. Null only when never inspected.
  final DateTime? nextDueAt;
  final bool dueIsEstimated;

  /// Whole calendar days from today to [nextDueAt]; negative = overdue.
  final int? daysToDue;
  final List<ReadinessFollowUp> openFollowUps;
  final DateTime? lastLoadTestAt;
  final DateTime? nextLoadTestDueAt;

  /// Earliest open scheduled task from today on.
  final DateTime? scheduledTaskNext;

  /// Needed lines that are short, for the unit's latest inspection and its
  /// open maintenance jobs.
  final int partsShortCount;
  final ReadinessStatus status;

  /// Worst first.
  final List<ReadinessReason> reasons;

  /// Id of the latest inspection (for navigating to its detail), if any.
  final String? latestInspectionId;

  bool get isOverdue => (daysToDue ?? 0) < 0;
  bool get hasFollowUps => openFollowUps.isNotEmpty;
  int get followUpCount => openFollowUps.length;
}

/// Counts for one week of the due-date histogram.
class DueWeekBucket {
  const DueWeekBucket(this.weekStart, this.count);

  /// Monday, local midnight.
  final DateTime weekStart;
  final int count;
}
