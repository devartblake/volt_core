import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'stock.dart';

/// The id the app uses for the main warehouse. In the cloud the warehouse row
/// is the tenant id; the mapping happens in the repository's row functions.
const String kMainLocationId = 'main';

enum LocationKind {
  warehouse('warehouse', 'Warehouse'),
  truck('truck', 'Truck'),
  other('other', 'Other');

  const LocationKind(this.wire, this.label);

  final String wire;
  final String label;

  static LocationKind fromWire(String? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return LocationKind.other;
  }
}

/// A place stock is kept: the main warehouse or a truck.
@immutable
class InventoryLocation {
  const InventoryLocation({
    required this.id,
    required this.name,
    this.kind = LocationKind.truck,
    this.vehicleId,
    this.assignedUserId,
    this.isActive = true,
    required this.updatedAt,
  });

  /// The main warehouse, which always exists.
  factory InventoryLocation.main() => InventoryLocation(
        id: kMainLocationId,
        name: 'Main warehouse',
        kind: LocationKind.warehouse,
        updatedAt: DateTime.utc(2000),
      );

  final String id;
  final String name;
  final LocationKind kind;

  /// Optional link to a fleet vehicle.
  final String? vehicleId;

  /// Optional technician (user id) this truck is assigned to.
  final String? assignedUserId;
  final bool isActive;
  final DateTime updatedAt;

  bool get isMain => id == kMainLocationId;
  bool get isTruck => kind == LocationKind.truck;

  InventoryLocation copyWith({
    String? name,
    Object? vehicleId = _keep,
    Object? assignedUserId = _keep,
    bool? isActive,
    DateTime? updatedAt,
  }) =>
      InventoryLocation(
        id: id,
        name: name ?? this.name,
        kind: kind,
        vehicleId: identical(vehicleId, _keep)
            ? this.vehicleId
            : vehicleId as String?,
        assignedUserId: identical(assignedUserId, _keep)
            ? this.assignedUserId
            : assignedUserId as String?,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.wire,
        'vehicleId': vehicleId,
        'assignedUserId': assignedUserId,
        'isActive': isActive,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static InventoryLocation? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    String? opt(Object? v) {
      final s = v?.toString() ?? '';
      return s.isEmpty ? null : s;
    }

    return InventoryLocation(
      id: id,
      name: json['name']?.toString() ?? '',
      kind: LocationKind.fromWire(json['kind']?.toString()),
      vehicleId: opt(json['vehicleId']),
      assignedUserId: opt(json['assignedUserId']),
      isActive: json['isActive'] != false,
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static String encode(InventoryLocation l) => jsonEncode(l.toJson());

  static InventoryLocation? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? fromJson(Map<String, dynamic>.from(v)) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Active trucks first by name, with the main warehouse at the top.
List<InventoryLocation> sortedLocations(Iterable<InventoryLocation> locations,
    {bool includeInactive = false}) {
  final list = [
    for (final l in locations)
      if (!l.isMain && (includeInactive || l.isActive)) l,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [InventoryLocation.main(), ...list];
}

/// On hand of [partId] at [locationId].
int onHandAt(
  Iterable<InventoryMovement> movements,
  String partId,
  String locationId,
) {
  var n = 0;
  for (final m in movements) {
    if (m.partId == partId &&
        m.locationId == locationId &&
        m.reason.changesOnHand) {
      n += m.qtyDelta;
    }
  }
  return n;
}

/// Why a transfer cannot be made, or null when it can.
String? transferProblem({
  required String fromId,
  required String toId,
  required int qty,
  required int onHandAtSource,
}) {
  if (fromId == toId) return 'Choose two different locations.';
  if (qty <= 0) return 'Enter a quantity above zero.';
  if (qty > onHandAtSource) {
    return onHandAtSource <= 0
        ? 'Nothing on hand at the source to move.'
        : 'Only $onHandAtSource on hand at the source.';
  }
  return null;
}

/// The two ledger lines of a transfer: negative at the source, positive at the
/// destination. Throws [ArgumentError] when [transferProblem] says it cannot
/// be made.
({InventoryMovement out, InventoryMovement into}) planTransfer({
  required String partId,
  required String fromId,
  required String toId,
  required int qty,
  required int onHandAtSource,
  required DateTime at,
  required String outId,
  required String intoId,
  String note = '',
  String? userId,
}) {
  final problem = transferProblem(
    fromId: fromId,
    toId: toId,
    qty: qty,
    onHandAtSource: onHandAtSource,
  );
  if (problem != null) throw ArgumentError(problem);
  return (
    out: InventoryMovement(
      id: outId,
      partId: partId,
      qtyDelta: -qty,
      reason: MovementReason.transfer,
      at: at,
      locationId: fromId,
      note: note,
      userId: userId,
    ),
    into: InventoryMovement(
      id: intoId,
      partId: partId,
      qtyDelta: qty,
      reason: MovementReason.transfer,
      at: at,
      locationId: toId,
      note: note,
      userId: userId,
    ),
  );
}
