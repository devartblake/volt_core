/// Input of the Fleet Readiness PDF. Pure Dart.
library;

import 'readiness_models.dart';
import 'readiness_summary.dart';

/// Everything the PDF needs.
class ReadinessExportData {
  const ReadinessExportData({
    required this.units,
    required this.summary,
    required this.asOf,
    this.filtered = false,
  });

  /// The units to list (already filtered).
  final List<ReadinessUnit> units;

  /// Fleet totals for the summary page (of the whole fleet).
  final ReadinessSummary summary;
  final DateTime asOf;

  /// True when [units] is a subset of the fleet.
  final bool filtered;
}
