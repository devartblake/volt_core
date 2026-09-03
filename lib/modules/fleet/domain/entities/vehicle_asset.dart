import 'package:uuid/uuid.dart';

/// Whether a tool is fit for work.
///
/// FMC / NMC — Fully and Non Mission Capable — are the terms already printed
/// on the paper receipt. Keeping the crew's vocabulary matters more than
/// inventing a tidier "ok / broken": the words on the screen should be the
/// words on the form the technician has been signing for years.
enum AssetReadiness { fmc, nmc }

extension AssetReadinessX on AssetReadiness {
  String get label => switch (this) {
        AssetReadiness.fmc => 'FMC',
        AssetReadiness.nmc => 'NMC',
      };

  /// The long form, for places with room to explain it.
  String get description => switch (this) {
        AssetReadiness.fmc => 'Fully mission capable',
        AssetReadiness.nmc => 'Not mission capable',
      };

  String get wire => name;

  static AssetReadiness fromWire(String? raw) {
    for (final value in AssetReadiness.values) {
      if (value.name == raw) return value;
    }
    return AssetReadiness.fmc;
  }
}

/// One physical tool, in one vehicle.
///
/// **One row per item, never a quantity.** The paper form lists the two Werner
/// 8ft ladders as two separate lines, and on the sample one is missing and the
/// other is not — a single row carrying `quantity: 2` cannot express that,
/// which is the whole reason the receipt exists.
class VehicleAsset {
  const VehicleAsset({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.catalogId,
    required this.assignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.serialNumber,
    this.readiness = AssetReadiness.fmc,
    this.isMissing = false,
    this.notes = '',
    this.retiredAt,
  });

  factory VehicleAsset.newDraft({
    required String tenantId,
    required String vehicleId,
    required String catalogId,
  }) {
    final now = DateTime.now().toUtc();
    return VehicleAsset(
      id: const Uuid().v4(),
      tenantId: tenantId,
      vehicleId: vehicleId,
      catalogId: catalogId,
      assignedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String tenantId;
  final String vehicleId;
  final String catalogId;

  /// Null when the tool carries no serial. The unique index is partial for the
  /// same reason as the part number's: '' would collide every unserialised
  /// tool with every other one.
  final String? serialNumber;

  final AssetReadiness readiness;

  /// Standing state, updated by the most recent receipt. Distinct from
  /// [retiredAt]: a missing ladder is expected back, a retired one is not.
  final bool isMissing;

  final String notes;
  final DateTime assignedAt;

  /// Set when the tool leaves the fleet for good — sold, destroyed, written
  /// off. A retired asset stays in the record so old receipts still resolve.
  final DateTime? retiredAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRetired => retiredAt != null;

  /// Whether this wants somebody's attention on the next receipt.
  bool get needsAttention =>
      !isRetired && (isMissing || readiness == AssetReadiness.nmc);

  VehicleAsset copyWith({
    String? serialNumber,
    bool clearSerialNumber = false,
    AssetReadiness? readiness,
    bool? isMissing,
    String? notes,
    DateTime? retiredAt,
    bool clearRetiredAt = false,
    DateTime? updatedAt,
  }) {
    return VehicleAsset(
      id: id,
      tenantId: tenantId,
      vehicleId: vehicleId,
      catalogId: catalogId,
      serialNumber:
          clearSerialNumber ? null : (serialNumber ?? this.serialNumber),
      readiness: readiness ?? this.readiness,
      isMissing: isMissing ?? this.isMissing,
      notes: notes ?? this.notes,
      assignedAt: assignedAt,
      retiredAt: clearRetiredAt ? null : (retiredAt ?? this.retiredAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Normalise a serial for comparison: upper case, trimmed. Matches the unique
/// index, so a duplicate is caught at the keyboard rather than as a 23505.
String normalizeSerial(String? raw) => (raw ?? '').trim().toUpperCase();
