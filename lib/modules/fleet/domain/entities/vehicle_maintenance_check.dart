import 'package:uuid/uuid.dart';

/// How a checked component came back.
///
/// Three states, not a boolean: "needs watching at the next service" is the
/// most common real answer on a walk-around, and collapsing it into pass/fail
/// means it gets recorded as a pass and forgotten.
enum CheckStatus { ok, attention, fail }

extension CheckStatusX on CheckStatus {
  String get label => switch (this) {
        CheckStatus.ok => 'OK',
        CheckStatus.attention => 'Needs attention',
        CheckStatus.fail => 'Failed',
      };

  /// Value stored in the `*_status` columns.
  String get wire => name;

  static CheckStatus fromWire(String? raw) {
    for (final value in CheckStatus.values) {
      if (value.name == raw) return value;
    }
    return CheckStatus.ok;
  }

  bool get needsFollowUp => this != CheckStatus.ok;
}

/// One completed vehicle maintenance checklist.
///
/// An event, not a set of columns on the vehicle: the paper form is filled in
/// repeatedly and "when was Truck A last serviced, and by whom?" is the
/// question the record exists to answer. Columns that get overwritten cannot.
class VehicleMaintenanceCheck {
  const VehicleMaintenanceCheck({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.checkedAt,
    required this.createdAt,
    required this.updatedAt,
    this.checkedByUserId,
    this.odometer = 0,
    this.lastOilChangeAt,
    this.lastLubricantCheckAt,
    this.odometerAtLastService,
    this.brakeStatus = CheckStatus.ok,
    this.batteryStatus = CheckStatus.ok,
    this.notes = '',
  });

  /// A blank check for [vehicleId], pre-filled with the reading the vehicle
  /// already carries so the common case is "type the new mileage over it".
  factory VehicleMaintenanceCheck.newDraft({
    required String tenantId,
    required String vehicleId,
    int odometer = 0,
    String? checkedByUserId,
  }) {
    final now = DateTime.now().toUtc();
    return VehicleMaintenanceCheck(
      id: const Uuid().v4(),
      tenantId: tenantId,
      vehicleId: vehicleId,
      checkedAt: now,
      createdAt: now,
      updatedAt: now,
      odometer: odometer,
      checkedByUserId: checkedByUserId,
    );
  }

  final String id;
  final String tenantId;
  final String vehicleId;

  /// When the walk-around happened — not when the row was written. A check
  /// entered on Monday for Friday's inspection is backdated on purpose.
  final DateTime checkedAt;

  final String? checkedByUserId;
  final int odometer;
  final DateTime? lastOilChangeAt;
  final DateTime? lastLubricantCheckAt;
  final int? odometerAtLastService;
  final CheckStatus brakeStatus;
  final CheckStatus batteryStatus;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether anything on this check wants following up.
  bool get needsFollowUp =>
      brakeStatus.needsFollowUp || batteryStatus.needsFollowUp;

  /// Miles since the last recorded service, or null when either end is
  /// unknown.
  int? get milesSinceService {
    final since = odometerAtLastService;
    if (since == null) return null;
    final delta = odometer - since;
    return delta < 0 ? null : delta;
  }

  VehicleMaintenanceCheck copyWith({
    DateTime? checkedAt,
    String? checkedByUserId,
    int? odometer,
    DateTime? lastOilChangeAt,
    bool clearLastOilChange = false,
    DateTime? lastLubricantCheckAt,
    bool clearLastLubricantCheck = false,
    int? odometerAtLastService,
    bool clearOdometerAtLastService = false,
    CheckStatus? brakeStatus,
    CheckStatus? batteryStatus,
    String? notes,
    DateTime? updatedAt,
  }) {
    return VehicleMaintenanceCheck(
      id: id,
      tenantId: tenantId,
      vehicleId: vehicleId,
      checkedAt: checkedAt ?? this.checkedAt,
      checkedByUserId: checkedByUserId ?? this.checkedByUserId,
      odometer: odometer ?? this.odometer,
      lastOilChangeAt:
          clearLastOilChange ? null : (lastOilChangeAt ?? this.lastOilChangeAt),
      lastLubricantCheckAt: clearLastLubricantCheck
          ? null
          : (lastLubricantCheckAt ?? this.lastLubricantCheckAt),
      odometerAtLastService: clearOdometerAtLastService
          ? null
          : (odometerAtLastService ?? this.odometerAtLastService),
      brakeStatus: brakeStatus ?? this.brakeStatus,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Raised when a check reports fewer miles than the vehicle already has.
///
/// The plan left this open: is a lower reading a typo to reject, or a
/// correction to accept? It is overwhelmingly a typo — a transposed digit on a
/// six-figure number — but it is legitimately a correction after a cluster
/// replacement, so refusing outright would make the app wrong about a real
/// vehicle.
///
/// So it is refused *by default* and the caller may retry with
/// `allowOdometerRollback: true`. That way the common case is caught at the
/// keyboard and the rare case is still recordable, with the person entering it
/// having said out loud that they meant it.
class OdometerWentBackwards implements Exception {
  const OdometerWentBackwards({
    required this.recorded,
    required this.previous,
  });

  /// The reading just entered.
  final int recorded;

  /// What the vehicle already had.
  final int previous;

  @override
  String toString() =>
      'This check reads $recorded miles but the vehicle already shows '
      '$previous. Check for a typo — or confirm if the odometer really was '
      'replaced or corrected.';
}
