import 'package:uuid/uuid.dart';

/// What kind of vehicle this is. Drives the icon and nothing else so far.
enum VehicleType { van, truck, other }

/// Where a vehicle is in its lifecycle.
///
/// `maintenance` rather than the plan's "in_service": *in service* reads as
/// both "in use" and "being serviced", which are opposites here.
enum VehicleStatus { active, maintenance, outOfService, retired }

extension VehicleTypeX on VehicleType {
  String get label => switch (this) {
        VehicleType.van => 'Van',
        VehicleType.truck => 'Truck',
        VehicleType.other => 'Other',
      };

  /// Value stored in `fleet_vehicles.vehicle_type`.
  String get wire => name;

  static VehicleType fromWire(String? raw) {
    for (final value in VehicleType.values) {
      if (value.name == raw) return value;
    }
    return VehicleType.other;
  }
}

extension VehicleStatusX on VehicleStatus {
  String get label => switch (this) {
        VehicleStatus.active => 'Active',
        VehicleStatus.maintenance => 'In maintenance',
        VehicleStatus.outOfService => 'Out of service',
        VehicleStatus.retired => 'Retired',
      };

  /// Value stored in `fleet_vehicles.status`.
  ///
  /// **Not** [name]: the check constraint spells the two-word states with an
  /// underscore, and sending `outOfService` fails it. Same trap as
  /// `UserRoleX.wire`.
  String get wire => switch (this) {
        VehicleStatus.active => 'active',
        VehicleStatus.maintenance => 'maintenance',
        VehicleStatus.outOfService => 'out_of_service',
        VehicleStatus.retired => 'retired',
      };

  static VehicleStatus fromWire(String? raw) {
    for (final value in VehicleStatus.values) {
      if (value.wire == raw) return value;
    }
    return VehicleStatus.active;
  }

  /// Whether a vehicle in this state can be dispatched.
  bool get isDispatchable => this == VehicleStatus.active;
}

/// A vehicle in the fleet.
///
/// Deliberately not an `EquipmentEntity`: equipment is the field-service assets
/// we *inspect*, identified by serial or inspection history. A vehicle is
/// identified by its VIN and tracked by its odometer. See
/// docs/fleet_and_vehicle_assets_plan.md §1.
class VehicleEntity {
  const VehicleEntity({
    required this.id,
    required this.tenantId,
    required this.designation,
    required this.createdAt,
    required this.updatedAt,
    this.vin,
    this.licensePlate = '',
    this.make = '',
    this.model = '',
    this.modelYear,
    this.vehicleType = VehicleType.van,
    this.odometer = 0,
    this.status = VehicleStatus.active,
    this.assignedToUserId,
    this.notes = '',
    this.lastCheckAt,
  });

  factory VehicleEntity.newDraft({required String tenantId}) {
    final now = DateTime.now().toUtc();
    return VehicleEntity(
      id: const Uuid().v4(),
      tenantId: tenantId,
      designation: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String tenantId;

  /// How the crew refers to it — "Truck A", "Work Van B". This is what heads a
  /// paper form, so it is the human key rather than the VIN.
  final String designation;

  final String? vin;
  final String licensePlate;
  final String make;
  final String model;
  final int? modelYear;
  final VehicleType vehicleType;
  final int odometer;
  final VehicleStatus status;

  /// The technician stationed to this vehicle.
  ///
  /// They are responsible for it and its assets, and they sign for it when it
  /// is dispatched. This is also what scopes a tech's visibility: RLS lets a
  /// technician read only the vehicle whose id matches theirs.
  final String? assignedToUserId;

  final String notes;

  /// When the most recent maintenance check happened, cached from
  /// `vehicle_maintenance_checks` so the fleet list does not need a
  /// correlated subquery per row. Only ever moves forward — a backdated check
  /// synced late must not drag it back.
  final DateTime? lastCheckAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAssigned => (assignedToUserId ?? '').isNotEmpty;

  /// "Ford Transit", or empty when neither is recorded.
  String get makeModel =>
      [make.trim(), model.trim()].where((part) => part.isNotEmpty).join(' ');

  /// Label for lists and page titles. Never empty, so two half-filled records
  /// are still distinguishable — the same reasoning as
  /// `inspectionDisplayTitle`.
  String get displayTitle {
    final trimmed = designation.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (makeModel.isNotEmpty) return makeModel;
    if ((licensePlate).trim().isNotEmpty) return licensePlate.trim();
    return 'Unnamed vehicle';
  }

  VehicleEntity copyWith({
    String? designation,
    String? vin,
    bool clearVin = false,
    String? licensePlate,
    String? make,
    String? model,
    int? modelYear,
    bool clearModelYear = false,
    VehicleType? vehicleType,
    int? odometer,
    VehicleStatus? status,
    String? assignedToUserId,
    bool clearAssignee = false,
    String? notes,
    DateTime? lastCheckAt,
    DateTime? updatedAt,
  }) {
    return VehicleEntity(
      id: id,
      tenantId: tenantId,
      designation: designation ?? this.designation,
      vin: clearVin ? null : (vin ?? this.vin),
      licensePlate: licensePlate ?? this.licensePlate,
      make: make ?? this.make,
      model: model ?? this.model,
      modelYear: clearModelYear ? null : (modelYear ?? this.modelYear),
      vehicleType: vehicleType ?? this.vehicleType,
      odometer: odometer ?? this.odometer,
      status: status ?? this.status,
      assignedToUserId:
          clearAssignee ? null : (assignedToUserId ?? this.assignedToUserId),
      notes: notes ?? this.notes,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Characters a VIN may contain.
///
/// I, O and Q are excluded from the VIN alphabet by standard, precisely because
/// they are misread as 1, 0 and 0 — which is the failure mode when somebody
/// copies one off a doorframe by hand. Rejecting them catches the transcription
/// error at the keyboard rather than letting two vehicles collide later.
const String kVinAlphabet = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';

/// Normalise user input into storage form: upper case, no spaces or dashes.
String normalizeVin(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Null when [raw] is an acceptable VIN, otherwise the reason it is not.
///
/// Blank is acceptable — a vehicle is entered before anyone walks out to read
/// the VIN off it, and refusing to save until then would push the record onto
/// a sticky note.
String? validateVin(String? raw) {
  final vin = normalizeVin((raw ?? '').trim());
  if (vin.isEmpty) return null;

  if (vin.length != 17) {
    return 'A VIN is 17 characters (this one has ${vin.length}).';
  }
  for (final unit in vin.split('')) {
    if (!kVinAlphabet.contains(unit)) {
      return 'A VIN cannot contain "$unit" — I, O and Q are not used, to '
          'avoid confusion with 1 and 0.';
    }
  }
  return null;
}
