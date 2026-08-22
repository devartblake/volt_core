import 'package:flutter/foundation.dart';

/// Service state of an asset, derived from its most recent inspection.
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

/// Supported field-service asset categories.
///
/// The database persists the stable [name], allowing additional categories to
/// be introduced later without a destructive schema migration.
enum AssetType {
  generator,
  transferSwitch,
  switchgear,
  panelboard,
  transformer,
  emergencyLighting,
  ups,
  evCharger,
  batteryEnergyStorage,
  other,
}

/// A physical asset the company inspects or maintains.
///
/// Assets may be derived from inspection history or entered into the shared
/// registry before their first inspection. Generator inspections remain the
/// first source, but the entity is intentionally not generator-specific.
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
    this.assetType = AssetType.generator,
    this.metadata = const {},
    this.siteId,
    this.registryId,
    this.identityKey,
    this.siteCode = '',
    this.siteGrade = '',
    this.lastInspection,
    this.hasInspectionLink = true,
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

  /// Broad asset category. Existing records default to [AssetType.generator].
  final AssetType assetType;

  /// Asset-type-specific values, such as generator kW or charger connector
  /// count. Generic identity and lifecycle fields remain first-class fields.
  final Map<String, dynamic> metadata;

  /// Tenant-owned service site selected for this asset, when it is known.
  final String? siteId;

  /// Shared registry row identity. Inspection-derived entities use a separate
  /// inspection id for navigation, so this is retained for safe edits.
  final String? registryId;

  /// Stable registry merge key, supplied by the remote equipment row.
  final String? identityKey;

  final String siteCode;

  /// 'Green' | 'Amber' | 'Red' from the latest inspection, when graded.
  final String siteGrade;

  final DateTime? lastInspection;

  /// Whether [id] points to an inspection/nameplate record that can be opened.
  /// Manually registered assets have no inspection until field work is done.
  final bool hasInspectionLink;

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
    AssetType? assetType,
    Map<String, dynamic>? metadata,
    String? siteId,
    bool clearSiteId = false,
    String? registryId,
    String? identityKey,
    String? siteCode,
    String? siteGrade,
    DateTime? lastInspection,
    bool? hasInspectionLink,
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
      assetType: assetType ?? this.assetType,
      metadata: metadata ?? this.metadata,
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      registryId: registryId ?? this.registryId,
      identityKey: identityKey ?? this.identityKey,
      siteCode: siteCode ?? this.siteCode,
      siteGrade: siteGrade ?? this.siteGrade,
      lastInspection: lastInspection ?? this.lastInspection,
      hasInspectionLink: hasInspectionLink ?? this.hasInspectionLink,
      inspectionCount: inspectionCount ?? this.inspectionCount,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'EquipmentEntity($name, sn: $serialNumber, status: ${status.name})';
}
