import 'dart:convert';

import 'package:flutter/material.dart';

/// The kinds of part a generator takes. Each has the same four fields on an
/// item (part number, quantity, date used, part name / manufacturer); what
/// differs is whether there can be more than one.
enum MaterialSlot {
  airFilter('air_filter', 'Air filter', Icons.air_outlined),
  fuelFilter('fuel_filter', 'Fuel filter', Icons.local_gas_station_outlined,
      multiple: true),
  oilFilter('oil_filter', 'Oil filter', Icons.oil_barrel_outlined,
      multiple: true),
  lubeFilter('lube_filter', 'Lube filter', Icons.water_drop_outlined,
      multiple: true),
  fuelWaterSeparator('fuel_water_separator', 'Fuel/water separator',
      Icons.filter_alt_outlined),
  coolantFilter('coolant_filter', 'Coolant filter', Icons.ac_unit_outlined),
  battery('battery', 'Battery', Icons.battery_charging_full_outlined,
      multiple: true, rolesAreLabelled: false),
  blockHeater('block_heater', 'Block heater', Icons.whatshot_outlined),
  racorFilter('racor_filter', 'Racor filter', Icons.filter_list_outlined),
  additionalParts('additional_parts', 'Additional parts',
      Icons.add_box_outlined,
      multiple: true, usesRoles: false);

  const MaterialSlot(
    this.wire,
    this.label,
    this.icon, {
    this.multiple = false,
    this.usesRoles = true,
    // Batteries are told apart by position, not primary/secondary wording, but
    // the same role field carries it.
    this.rolesAreLabelled = true,
  });

  /// Stable name stored on the device and in the database.
  final String wire;
  final String label;
  final IconData icon;

  /// More than one item may be recorded.
  final bool multiple;

  /// Whether items are designated primary / secondary. Additional parts are a
  /// plain list.
  final bool usesRoles;

  final bool rolesAreLabelled;

  static MaterialSlot? fromWire(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Primary or secondary, on slots that can hold more than one item.
enum MaterialRole {
  none('none', ''),
  primary('primary', 'Primary'),
  secondary('secondary', 'Secondary');

  const MaterialRole(this.wire, this.label);

  final String wire;
  final String label;

  static MaterialRole fromWire(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return none;
  }
}

/// What a set of items belongs to.
enum MaterialOwnerType {
  /// A generator's parts profile.
  generator('generator'),
  inspection('inspection'),
  maintenance('maintenance');

  const MaterialOwnerType(this.wire);

  final String wire;
}

/// One part: on a generator's profile, or on a job.
@immutable
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.slot,
    this.role = MaterialRole.none,
    this.partNumber = '',
    this.partName = '',
    this.manufacturer = '',
    this.quantity = 1,
    this.dateUsed,
    this.needsReplacement = false,
    this.notes = '',
    this.usedMovementId,
  });

  final String id;
  final MaterialSlot slot;
  final MaterialRole role;

  final String partNumber;

  /// What the part is called ("Fleetguard oil filter").
  final String partName;
  final String manufacturer;

  /// Always at least 0; whole numbers.
  final int quantity;

  /// When it was fitted. Null until that is true - never auto-filled.
  final DateTime? dateUsed;

  /// On an inspection: due for replacement, so the follow-up job needs it.
  final bool needsReplacement;
  final String notes;

  /// The ledger movement made by "Mark used", so tapping twice cannot take
  /// stock twice. Null until then.
  final String? usedMovementId;

  bool get hasPartNumber => partNumber.trim().isNotEmpty;

  /// Nothing recorded beyond the defaults.
  bool get isBlank =>
      partNumber.trim().isEmpty &&
      partName.trim().isEmpty &&
      manufacturer.trim().isEmpty &&
      dateUsed == null &&
      !needsReplacement &&
      notes.trim().isEmpty;

  MaterialItem copyWith({
    MaterialRole? role,
    String? partNumber,
    String? partName,
    String? manufacturer,
    int? quantity,
    Object? dateUsed = _keep,
    bool? needsReplacement,
    String? notes,
    Object? usedMovementId = _keep,
  }) {
    return MaterialItem(
      id: id,
      slot: slot,
      role: role ?? this.role,
      partNumber: partNumber ?? this.partNumber,
      partName: partName ?? this.partName,
      manufacturer: manufacturer ?? this.manufacturer,
      quantity: quantity == null ? this.quantity : quantity < 0 ? 0 : quantity,
      dateUsed:
          identical(dateUsed, _keep) ? this.dateUsed : dateUsed as DateTime?,
      needsReplacement: needsReplacement ?? this.needsReplacement,
      notes: notes ?? this.notes,
      usedMovementId: identical(usedMovementId, _keep)
          ? this.usedMovementId
          : usedMovementId as String?,
    );
  }

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'slot': slot.wire,
        'role': role.wire,
        'partNumber': partNumber,
        'partName': partName,
        'manufacturer': manufacturer,
        'quantity': quantity,
        'dateUsed': dateUsed?.toIso8601String(),
        'needsReplacement': needsReplacement,
        'notes': notes,
        if (usedMovementId != null) 'usedMovementId': usedMovementId,
      };

  /// Null when the row's slot is not one this version knows, so a newer app's
  /// data never breaks an older one.
  static MaterialItem? fromJson(Map<String, dynamic> json) {
    final slot = MaterialSlot.fromWire(json['slot']?.toString());
    if (slot == null) return null;
    final qty = json['quantity'];
    return MaterialItem(
      id: json['id']?.toString() ?? '',
      slot: slot,
      role: MaterialRole.fromWire(json['role']?.toString()),
      partNumber: json['partNumber']?.toString() ?? '',
      partName: json['partName']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      quantity: qty is int ? qty : int.tryParse('$qty') ?? 1,
      dateUsed: DateTime.tryParse('${json['dateUsed'] ?? ''}'),
      needsReplacement: json['needsReplacement'] == true,
      notes: json['notes']?.toString() ?? '',
      usedMovementId: (json['usedMovementId']?.toString() ?? '').isEmpty
          ? null
          : json['usedMovementId'].toString(),
    );
  }

  static String encodeList(List<MaterialItem> items) =>
      jsonEncode([for (final i in items) i.toJson()]);

  static List<MaterialItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map)
            if (MaterialItem.fromJson(Map<String, dynamic>.from(e))
                case final item?)
              item,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MaterialItem && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
