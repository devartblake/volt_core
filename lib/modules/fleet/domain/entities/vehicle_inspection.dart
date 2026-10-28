import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'vehicle_maintenance_check.dart' show CheckStatus, CheckStatusX;

/// How often a walk-around is due.
enum InspectionCadence { weekly, monthly }

extension InspectionCadenceX on InspectionCadence {
  String get label => switch (this) {
        InspectionCadence.weekly => 'Weekly',
        InspectionCadence.monthly => 'Monthly',
      };

  Duration get interval => switch (this) {
        InspectionCadence.weekly => const Duration(days: 7),
        InspectionCadence.monthly => const Duration(days: 30),
      };

  static InspectionCadence fromWire(String? raw) =>
      InspectionCadence.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => InspectionCadence.weekly,
      );
}

/// One line on the walk-around checklist.
class InspectionItem {
  const InspectionItem(this.key, this.label);

  /// Stable storage key; never rename once records exist.
  final String key;
  final String label;
}

/// Weekly walk-around. A monthly inspection covers these *and* the extras.
const List<InspectionItem> kWeeklyInspectionItems = [
  InspectionItem('tires', 'Tires – condition and pressure'),
  InspectionItem('lights', 'Lights, signals and brake lights'),
  InspectionItem('brakes', 'Brakes and parking brake'),
  InspectionItem('fluids', 'Fluid levels (oil, coolant, washer)'),
  InspectionItem('battery', 'Battery and connections'),
  InspectionItem('wipers_glass', 'Wipers and windshield'),
  InspectionItem('mirrors_horn', 'Mirrors and horn'),
  InspectionItem('seat_belts', 'Seat belts'),
  InspectionItem('body_damage', 'Body – new damage or leaks'),
  InspectionItem('emergency_kit', 'Fire extinguisher, first aid, triangles'),
  InspectionItem('cleanliness', 'Cab and cargo area clean and secured'),
  InspectionItem('documents', 'Registration and insurance on board'),
];

const List<InspectionItem> kMonthlyExtraInspectionItems = [
  InspectionItem('tread_depth', 'Tire tread depth and spare'),
  InspectionItem('belts_hoses', 'Belts and hoses'),
  InspectionItem('battery_terminals', 'Battery terminals – corrosion'),
  InspectionItem('undercarriage', 'Undercarriage, exhaust and suspension'),
  InspectionItem('extinguisher_tag', 'Fire extinguisher gauge and tag date'),
  InspectionItem('first_aid_stock', 'First aid kit stocked and in date'),
  InspectionItem('fluid_leaks', 'Fluid leaks under the vehicle'),
  InspectionItem('tools_secured', 'Tools and equipment secured'),
];

List<InspectionItem> inspectionItemsFor(InspectionCadence cadence) => [
      ...kWeeklyInspectionItems,
      if (cadence == InspectionCadence.monthly) ...kMonthlyExtraInspectionItems,
    ];

/// A completed weekly or monthly vehicle inspection.
class VehicleInspection {
  const VehicleInspection({
    required this.id,
    required this.vehicleId,
    required this.cadence,
    required this.inspectedAt,
    required this.createdAt,
    this.inspectorUserId,
    this.inspectorName = '',
    this.odometer = 0,
    this.results = const {},
    this.itemNotes = const {},
    this.notes = '',
  });

  factory VehicleInspection.newDraft({
    required String vehicleId,
    required InspectionCadence cadence,
    int odometer = 0,
    String? inspectorUserId,
    String inspectorName = '',
  }) {
    final now = DateTime.now();
    return VehicleInspection(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      cadence: cadence,
      inspectedAt: now,
      createdAt: now,
      odometer: odometer,
      inspectorUserId: inspectorUserId,
      inspectorName: inspectorName,
      results: {
        for (final item in inspectionItemsFor(cadence)) item.key: CheckStatus.ok,
      },
    );
  }

  final String id;
  final String vehicleId;
  final InspectionCadence cadence;
  final DateTime inspectedAt;
  final DateTime createdAt;
  final String? inspectorUserId;
  final String inspectorName;
  final int odometer;
  final Map<String, CheckStatus> results;
  final Map<String, String> itemNotes;
  final String notes;

  /// Items that did not come back OK.
  int get issueCount => results.values.where((s) => s.needsFollowUp).length;
  int get failCount =>
      results.values.where((s) => s == CheckStatus.fail).length;
  bool get hasIssues => issueCount > 0;

  VehicleInspection copyWith({
    DateTime? inspectedAt,
    int? odometer,
    Map<String, CheckStatus>? results,
    Map<String, String>? itemNotes,
    String? notes,
    String? inspectorName,
  }) =>
      VehicleInspection(
        id: id,
        vehicleId: vehicleId,
        cadence: cadence,
        inspectedAt: inspectedAt ?? this.inspectedAt,
        createdAt: createdAt,
        inspectorUserId: inspectorUserId,
        inspectorName: inspectorName ?? this.inspectorName,
        odometer: odometer ?? this.odometer,
        results: results ?? this.results,
        itemNotes: itemNotes ?? this.itemNotes,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleId': vehicleId,
        'cadence': cadence.name,
        'inspectedAt': inspectedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'inspectorUserId': inspectorUserId,
        'inspectorName': inspectorName,
        'odometer': odometer,
        'results': {for (final e in results.entries) e.key: e.value.wire},
        'itemNotes': itemNotes,
        'notes': notes,
      };

  factory VehicleInspection.fromMap(Map<String, dynamic> map) {
    final rawResults = (map['results'] as Map?) ?? const {};
    final rawNotes = (map['itemNotes'] as Map?) ?? const {};
    return VehicleInspection(
      id: map['id'] as String,
      vehicleId: map['vehicleId'] as String? ?? '',
      cadence: InspectionCadenceX.fromWire(map['cadence'] as String?),
      inspectedAt: DateTime.tryParse(map['inspectedAt'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      inspectorUserId: map['inspectorUserId'] as String?,
      inspectorName: map['inspectorName'] as String? ?? '',
      odometer: (map['odometer'] as num?)?.toInt() ?? 0,
      results: {
        for (final e in rawResults.entries)
          e.key as String: CheckStatusX.fromWire(e.value as String?),
      },
      itemNotes: {
        for (final e in rawNotes.entries) e.key as String: '${e.value}',
      },
      notes: map['notes'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory VehicleInspection.fromJson(String source) =>
      VehicleInspection.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Where a cadence stands for one vehicle.
enum InspectionDueState { never, ok, dueSoon, overdue }

class InspectionStatus {
  const InspectionStatus(this.state, this.lastAt, this.dueAt);

  final InspectionDueState state;
  final DateTime? lastAt;
  final DateTime? dueAt;

  /// [inspections] must be for one vehicle; any order.
  static InspectionStatus compute(
    InspectionCadence cadence,
    Iterable<VehicleInspection> inspections, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    DateTime? last;
    for (final i in inspections) {
      // A monthly inspection covers everything a weekly one does, so it also
      // resets the weekly clock.
      final covers = i.cadence == cadence ||
          (cadence == InspectionCadence.weekly &&
              i.cadence == InspectionCadence.monthly);
      if (!covers) continue;
      if (last == null || i.inspectedAt.isAfter(last)) last = i.inspectedAt;
    }
    if (last == null) {
      return const InspectionStatus(InspectionDueState.never, null, null);
    }

    final due = last.add(cadence.interval);
    final soon = due.subtract(
      cadence == InspectionCadence.weekly
          ? const Duration(days: 1)
          : const Duration(days: 5),
    );
    final state = clock.isAfter(due)
        ? InspectionDueState.overdue
        : clock.isAfter(soon)
            ? InspectionDueState.dueSoon
            : InspectionDueState.ok;
    return InspectionStatus(state, last, due);
  }
}
