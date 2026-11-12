import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'vehicle_maintenance_check.dart' show CheckStatus, CheckStatusX;

/// How often a walk-around is due.
///
/// Daily is the pre-trip check the assigned person does before taking the
/// vehicle out. Weekly and monthly are the progressively more thorough ones.
enum InspectionCadence { daily, weekly, monthly }

extension InspectionCadenceX on InspectionCadence {
  String get label => switch (this) {
        InspectionCadence.daily => 'Daily',
        InspectionCadence.weekly => 'Weekly',
        InspectionCadence.monthly => 'Monthly',
      };

  Duration get interval => switch (this) {
        InspectionCadence.daily => const Duration(days: 1),
        InspectionCadence.weekly => const Duration(days: 7),
        InspectionCadence.monthly => const Duration(days: 30),
      };

  static InspectionCadence fromWire(String? raw) =>
      InspectionCadence.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => InspectionCadence.weekly,
      );
}

/// The four views of the vehicle that every inspection must photograph, one
/// separate photo each.
enum InspectionPhotoSlot { front, back, driverSide, passengerSide }

extension InspectionPhotoSlotX on InspectionPhotoSlot {
  /// Stored on the photo (`PhotoAttachment.slot`). Never rename.
  String get key => switch (this) {
        InspectionPhotoSlot.front => 'front',
        InspectionPhotoSlot.back => 'back',
        InspectionPhotoSlot.driverSide => 'driver_side',
        InspectionPhotoSlot.passengerSide => 'passenger_side',
      };

  String get label => switch (this) {
        InspectionPhotoSlot.front => 'Front',
        InspectionPhotoSlot.back => 'Back',
        InspectionPhotoSlot.driverSide => 'Driver side',
        InspectionPhotoSlot.passengerSide => 'Passenger side',
      };

  static InspectionPhotoSlot? fromKey(String? raw) {
    for (final slot in InspectionPhotoSlot.values) {
      if (slot.key == raw) return slot;
    }
    return null;
  }
}

/// One line on the walk-around checklist.
class InspectionItem {
  const InspectionItem(this.key, this.label);

  /// Stable storage key; never rename once records exist.
  final String key;
  final String label;
}

/// The pre-trip check, done each day before the vehicle is taken out.
const List<InspectionItem> kDailyInspectionItems = [
  InspectionItem('tires', 'Tires - no flats, damage or low pressure'),
  InspectionItem('lights', 'Headlights, brake lights and turn signals'),
  InspectionItem('brakes', 'Brakes - pedal feel and parking brake'),
  InspectionItem('steering', 'Steering feels normal'),
  InspectionItem('dash_warnings', 'No warning lights on the dashboard'),
  InspectionItem('fluid_leaks', 'No fluid leaks under the vehicle'),
  InspectionItem('windshield_wipers', 'Windshield, wipers and washer fluid'),
  InspectionItem('mirrors_horn', 'Mirrors and horn'),
  InspectionItem('seat_belts', 'Seat belts'),
  InspectionItem('body_damage', 'No new body damage'),
  InspectionItem('fuel_level', 'Fuel level is enough for the day'),
  InspectionItem('emergency_kit', 'Fire extinguisher, first aid and triangles'),
  InspectionItem('cargo_secured', 'Tools and cargo secured'),
  InspectionItem('documents', 'Registration and insurance on board'),
];

/// Weekly walk-around. A monthly inspection covers these *and* the extras.
const List<InspectionItem> kWeeklyInspectionItems = [
  InspectionItem('tires', 'Tires - condition and pressure'),
  InspectionItem('lights', 'Lights, signals and brake lights'),
  InspectionItem('brakes', 'Brakes and parking brake'),
  InspectionItem('fluids', 'Fluid levels (oil, coolant, washer)'),
  InspectionItem('battery', 'Battery and connections'),
  InspectionItem('wipers_glass', 'Wipers and windshield'),
  InspectionItem('mirrors_horn', 'Mirrors and horn'),
  InspectionItem('seat_belts', 'Seat belts'),
  InspectionItem('body_damage', 'Body - new damage or leaks'),
  InspectionItem('emergency_kit', 'Fire extinguisher, first aid, triangles'),
  InspectionItem('cleanliness', 'Cab and cargo area clean and secured'),
  InspectionItem('documents', 'Registration and insurance on board'),
];

const List<InspectionItem> kMonthlyExtraInspectionItems = [
  InspectionItem('tread_depth', 'Tire tread depth and spare'),
  InspectionItem('belts_hoses', 'Belts and hoses'),
  InspectionItem('battery_terminals', 'Battery terminals - corrosion'),
  InspectionItem('undercarriage', 'Undercarriage, exhaust and suspension'),
  InspectionItem('extinguisher_tag', 'Fire extinguisher gauge and tag date'),
  InspectionItem('first_aid_stock', 'First aid kit stocked and in date'),
  InspectionItem('fluid_leaks', 'Fluid leaks under the vehicle'),
  InspectionItem('tools_secured', 'Tools and equipment secured'),
];

List<InspectionItem> inspectionItemsFor(InspectionCadence cadence) =>
    switch (cadence) {
      InspectionCadence.daily => kDailyInspectionItems,
      InspectionCadence.weekly => kWeeklyInspectionItems,
      InspectionCadence.monthly => [
          ...kWeeklyInspectionItems,
          ...kMonthlyExtraInspectionItems,
        ],
    };

/// A completed daily, weekly or monthly vehicle inspection.
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
    this.driverName = '',
    this.driverSignaturePath,
    this.dispatcherName = '',
    this.dispatcherSignaturePath,
    this.signedAt,
  });

  /// A blank inspection. **No item is answered yet**: every question must be
  /// answered on purpose, so a pre-ticked "OK" cannot stand in for a check
  /// nobody actually made.
  factory VehicleInspection.newDraft({
    required String vehicleId,
    required InspectionCadence cadence,
    int odometer = 0,
    String? inspectorUserId,
    String inspectorName = '',
    String driverName = '',
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
      driverName: driverName,
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

  /// Answers by item key. A key that is absent has not been answered.
  final Map<String, CheckStatus> results;
  final Map<String, String> itemNotes;
  final String notes;

  /// The person the vehicle is assigned to, who signs for taking it.
  final String driverName;
  final String? driverSignaturePath;

  /// The dispatcher who signs off the inspection.
  final String dispatcherName;
  final String? dispatcherSignaturePath;
  final DateTime? signedAt;

  /// Items that did not come back OK.
  int get issueCount => results.values.where((s) => s.needsFollowUp).length;
  int get failCount =>
      results.values.where((s) => s == CheckStatus.fail).length;
  bool get hasIssues => issueCount > 0;

  bool get isSigned =>
      (driverSignaturePath ?? '').isNotEmpty &&
      (dispatcherSignaturePath ?? '').isNotEmpty;

  VehicleInspection copyWith({
    DateTime? inspectedAt,
    int? odometer,
    Map<String, CheckStatus>? results,
    Map<String, String>? itemNotes,
    String? notes,
    String? inspectorName,
    String? driverName,
    String? driverSignaturePath,
    String? dispatcherName,
    String? dispatcherSignaturePath,
    DateTime? signedAt,
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
        driverName: driverName ?? this.driverName,
        driverSignaturePath: driverSignaturePath ?? this.driverSignaturePath,
        dispatcherName: dispatcherName ?? this.dispatcherName,
        dispatcherSignaturePath:
            dispatcherSignaturePath ?? this.dispatcherSignaturePath,
        signedAt: signedAt ?? this.signedAt,
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
        'driverName': driverName,
        'driverSignaturePath': driverSignaturePath,
        'dispatcherName': dispatcherName,
        'dispatcherSignaturePath': dispatcherSignaturePath,
        'signedAt': signedAt?.toIso8601String(),
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
      driverName: map['driverName'] as String? ?? '',
      driverSignaturePath: map['driverSignaturePath'] as String?,
      dispatcherName: map['dispatcherName'] as String? ?? '',
      dispatcherSignaturePath: map['dispatcherSignaturePath'] as String?,
      signedAt: DateTime.tryParse(map['signedAt'] as String? ?? ''),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory VehicleInspection.fromJson(String source) =>
      VehicleInspection.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Everything still missing before an inspection may be completed, in the
/// order the person should fix it. Empty means it is complete.
///
/// Pure, so the rule can be tested and reused: the form shows the result in a
/// dialog and refuses to save until the list is empty.
List<String> inspectionGaps({
  required InspectionCadence cadence,
  required Map<String, CheckStatus> results,
  required Map<String, String> itemNotes,
  required Set<InspectionPhotoSlot> photoSlots,
  required String driverName,
  required String dispatcherName,
  required bool hasDriverSignature,
  required bool hasDispatcherSignature,
  required bool hasOdometer,
}) {
  final gaps = <String>[];

  if (!hasOdometer) gaps.add('Odometer reading');

  final items = inspectionItemsFor(cadence);
  final unanswered = [
    for (final item in items)
      if (!results.containsKey(item.key)) item.label,
  ];
  if (unanswered.isNotEmpty) {
    const show = 6;
    for (final label in unanswered.take(show)) {
      gaps.add('Answer: $label');
    }
    if (unanswered.length > show) {
      gaps.add('...and ${unanswered.length - show} more unanswered questions');
    }
  }

  for (final item in items) {
    final status = results[item.key];
    if (status != null &&
        status.needsFollowUp &&
        (itemNotes[item.key] ?? '').trim().isEmpty) {
      gaps.add('Explain what is wrong: ${item.label}');
    }
  }

  for (final slot in InspectionPhotoSlot.values) {
    if (!photoSlots.contains(slot)) gaps.add('Photo: ${slot.label} of the vehicle');
  }

  if (driverName.trim().isEmpty) gaps.add("Assigned person's name");
  if (!hasDriverSignature) gaps.add("Assigned person's signature");
  if (dispatcherName.trim().isEmpty) gaps.add("Dispatcher's name");
  if (!hasDispatcherSignature) gaps.add("Dispatcher's signature");

  return gaps;
}

/// Where a cadence stands for one vehicle.
enum InspectionDueState { never, ok, dueSoon, overdue }

class InspectionStatus {
  const InspectionStatus(this.state, this.lastAt, this.dueAt);

  final InspectionDueState state;
  final DateTime? lastAt;
  final DateTime? dueAt;

  /// [inspections] must be for one vehicle; any order.
  ///
  /// A longer inspection covers the shorter ones: a monthly counts as a weekly
  /// and a daily, a weekly counts as a daily. Daily is judged by the calendar
  /// day (done today or not) rather than a rolling 24 hours, because the rule
  /// is "before taking the vehicle each day".
  static InspectionStatus compute(
    InspectionCadence cadence,
    Iterable<VehicleInspection> inspections, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    DateTime? last;
    for (final i in inspections) {
      if (i.cadence.index < cadence.index) continue; // shorter does not cover longer
      if (last == null || i.inspectedAt.isAfter(last)) last = i.inspectedAt;
    }
    if (last == null) {
      return const InspectionStatus(InspectionDueState.never, null, null);
    }

    if (cadence == InspectionCadence.daily) {
      final today = DateTime(clock.year, clock.month, clock.day);
      final lastDay = DateTime(last.year, last.month, last.day);
      final doneToday = !lastDay.isBefore(today);
      return InspectionStatus(
        doneToday ? InspectionDueState.ok : InspectionDueState.overdue,
        last,
        doneToday ? today.add(const Duration(days: 1)) : today,
      );
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
