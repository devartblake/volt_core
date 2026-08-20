import 'package:flutter/foundation.dart';

/// Service state of a generator, derived from its most recent inspection.
enum EquipmentStatus {
  /// Passing its last inspection.
  active,

  /// Not currently in service (no inspection on record).
  inactive,

  /// Last inspection recorded deficiencies or a Red/Amber grade.
  maintenance,

  /// Withdrawn from service.
  retired,
}

/// A generator the company inspects.
///
/// Equipment isn't a table the user maintains by hand — it is *derived* from
/// the inspection history: every inspection names a generator (make, model,
/// serial), and the nameplate record attached to it carries the plate details.
/// Grouping that history by serial number gives one row per physical unit,
/// showing its latest known state.
@immutable
class EquipmentEntity {
  const EquipmentEntity({
    required this.id,
    required this.name,
    required this.make,
    required this.model,
    required this.serialNumber,
    required this.voltage,
    required this.location,
    this.siteCode = '',
    this.siteGrade = '',
    this.lastInspection,
    this.inspectionCount = 0,
    this.status = EquipmentStatus.active,
  });

  /// The **inspection id** this row was derived from — the most recent one for
  /// this unit. Navigation opens `/nameplate/:inspectionId`, so this has to be
  /// an inspection id rather than a synthetic key.
  final String id;

  /// Display name: "make model", falling back to the site code or address.
  final String name;

  final String make;
  final String model;
  final String serialNumber;
  final String voltage;

  /// Where it lives — the address from the latest inspection.
  final String location;

  final String siteCode;

  /// 'Green' | 'Amber' | 'Red' from the latest inspection, when graded.
  final String siteGrade;

  final DateTime? lastInspection;

  /// How many inspections contributed to this record.
  final int inspectionCount;

  final EquipmentStatus status;

  /// Stable identity across inspections: the serial number when known,
  /// otherwise site + make + model, otherwise the inspection id itself.
  ///
  /// Serial numbers are hand-typed, so they're compared case-insensitively and
  /// with surrounding whitespace removed.
  static String identityKey({
    required String serialNumber,
    required String siteCode,
    required String make,
    required String model,
    required String fallbackId,
  }) {
    final serial = serialNumber.trim().toLowerCase();
    if (serial.isNotEmpty) return 'sn:$serial';

    final composite = [
      siteCode.trim().toLowerCase(),
      make.trim().toLowerCase(),
      model.trim().toLowerCase(),
    ].where((p) => p.isNotEmpty).join('|');

    return composite.isEmpty ? 'id:$fallbackId' : 'composite:$composite';
  }

  EquipmentEntity copyWith({
    String? id,
    String? name,
    String? make,
    String? model,
    String? serialNumber,
    String? voltage,
    String? location,
    String? siteCode,
    String? siteGrade,
    DateTime? lastInspection,
    int? inspectionCount,
    EquipmentStatus? status,
  }) {
    return EquipmentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      voltage: voltage ?? this.voltage,
      location: location ?? this.location,
      siteCode: siteCode ?? this.siteCode,
      siteGrade: siteGrade ?? this.siteGrade,
      lastInspection: lastInspection ?? this.lastInspection,
      inspectionCount: inspectionCount ?? this.inspectionCount,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'EquipmentEntity($name, sn: $serialNumber, status: ${status.name})';
}
