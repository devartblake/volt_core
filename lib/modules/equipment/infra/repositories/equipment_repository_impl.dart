import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/hive/hive_boxes.dart';
import '../../../inspections/infra/models/inspection.dart';
import '../../../inspections/infra/models/nameplate_data.dart';
import '../../domain/entities/equipment_entity.dart';
import 'equipment_repository.dart';

/// Builds the equipment registry from local inspection history.
///
/// There is no `equipment` table: a generator becomes "known" the first time
/// someone inspects it. This groups the inspection history by unit (serial
/// number where available) and reports each unit's latest known state, so the
/// registry stays correct with no extra data entry and works offline.
///
/// Nameplate records are the better source for plate details when present —
/// they're transcribed directly off the unit — so they take precedence over the
/// generator fields typed into the inspection form.
class EquipmentRepositoryImpl implements EquipmentRepository {
  const EquipmentRepositoryImpl();

  @override
  Future<List<EquipmentEntity>> listEquipment() async {
    if (!Hive.isBoxOpen(HiveBoxes.inspectionsBoxName)) return const [];

    final inspections = HiveBoxes.inspections.values.toList();
    if (inspections.isEmpty) return const [];

    // Nameplates keyed by the inspection they belong to.
    final nameplates = <String, NameplateData>{};
    if (Hive.isBoxOpen(HiveBoxes.nameplatesBoxName)) {
      for (final np in HiveBoxes.nameplates.values) {
        nameplates[np.inspectionId] = np;
      }
    }

    // Group inspections by physical unit.
    final grouped = <String, List<Inspection>>{};
    for (final ins in inspections) {
      final np = nameplates[ins.id];
      final key = EquipmentEntity.identityKey(
        serialNumber: _pick(np?.generatorSn, ins.generatorSerial),
        siteCode: ins.siteCode,
        make: _pick(np?.generatorMfr, ins.generatorMake),
        model: _pick(np?.generatorModel, ins.generatorModel),
        fallbackId: ins.id,
      );
      grouped.putIfAbsent(key, () => []).add(ins);
    }

    final equipment = <EquipmentEntity>[];
    for (final entry in grouped.entries) {
      final history = entry.value
        ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
      final latest = history.first;
      final np = nameplates[latest.id];

      final make = _pick(np?.generatorMfr, latest.generatorMake);
      final model = _pick(np?.generatorModel, latest.generatorModel);
      final serial = _pick(np?.generatorSn, latest.generatorSerial);
      final voltage = _pick(np?.volts, latest.voltageRating);

      equipment.add(
        EquipmentEntity(
          // The latest inspection's id: tapping through opens its nameplate.
          id: latest.id,
          name: _displayName(
            make: make,
            model: model,
            siteCode: latest.siteCode,
            address: latest.address,
          ),
          make: make,
          model: model,
          serialNumber: serial,
          voltage: voltage,
          location: latest.address.trim().isNotEmpty
              ? latest.address
              : latest.siteCode,
          siteCode: latest.siteCode,
          siteGrade: latest.siteGrade,
          lastInspection: latest.serviceDate,
          inspectionCount: history.length,
          status: _statusFor(latest),
        ),
      );
    }

    equipment.sort((a, b) {
      final at = a.lastInspection;
      final bt = b.lastInspection;
      if (at == null && bt == null) return a.name.compareTo(b.name);
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return equipment;
  }

  @override
  Future<EquipmentFacets> facets() async {
    final all = await listEquipment();

    List<String> distinct(String Function(EquipmentEntity) get) {
      final values = all
          .map(get)
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return values;
    }

    return EquipmentFacets(
      makes: distinct((e) => e.make),
      voltages: distinct((e) => e.voltage),
      locations: distinct((e) => e.location),
    );
  }

  /// First non-blank value; nameplate data wins over form-typed data.
  static String _pick(String? preferred, String fallback) {
    final p = preferred?.trim() ?? '';
    if (p.isNotEmpty) return p;
    return fallback.trim();
  }

  static String _displayName({
    required String make,
    required String model,
    required String siteCode,
    required String address,
  }) {
    final label = [make, model].where((p) => p.isNotEmpty).join(' ');
    if (label.isNotEmpty) return label;
    if (siteCode.trim().isNotEmpty) return siteCode.trim();
    if (address.trim().isNotEmpty) return address.trim();
    return 'Unidentified generator';
  }

  /// Service state from the latest inspection.
  ///
  /// A Red or Amber grade, or documented deficiencies, means the unit needs
  /// attention. Nothing in the inspection data expresses "retired", so that
  /// state is only reachable if the app later gains an explicit field.
  static EquipmentStatus _statusFor(Inspection latest) {
    final grade = latest.siteGrade.trim().toLowerCase();
    if (grade == 'red' || grade == 'amber' || latest.deficienciesDocumented) {
      return EquipmentStatus.maintenance;
    }
    return EquipmentStatus.active;
  }
}

/// Repository provider for the equipment registry.
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return const EquipmentRepositoryImpl();
});
