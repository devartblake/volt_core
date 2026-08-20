import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/hive/hive_boxes.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../../inspections/infra/models/inspection.dart';
import '../../../inspections/infra/models/nameplate_data.dart';
import '../../domain/entities/equipment_entity.dart';
import '../datasources/equipment_remote_datasource.dart';
import '../mappers/equipment_supabase_mapper.dart';
import 'equipment_repository.dart';

/// Builds the equipment registry.
///
/// Two sources, merged:
///
/// 1. **Local inspection history.** A generator becomes "known" the first time
///    someone inspects it, so the registry needs no separate data entry. This
///    is the offline-capable path and always wins on conflict — a unit just
///    inspected on this device is fresher than whatever the server holds.
/// 2. **The shared `equipment` table.** Units inspected on *other* devices, and
///    units entered before their first inspection, only exist here.
///
/// What is derived locally is also pushed back through [SyncService], so every
/// device converges on the same registry. Row ids are a deterministic UUIDv5 of
/// tenant + identity key, which is what makes a plain upsert merge rather than
/// duplicate.
class EquipmentRepositoryImpl implements EquipmentRepository {
  const EquipmentRepositoryImpl({EquipmentRemoteDatasource? remote})
      : _remote = remote;

  final EquipmentRemoteDatasource? _remote;

  @override
  Future<List<EquipmentEntity>> listEquipment() async {
    final local = _deriveFromInspections();

    // Push what we derived so other devices see it. Best-effort and
    // non-blocking: the queue handles retries.
    unawaited(_publish(local));

    // Copy before sorting: the no-inspections path yields a const list, and
    // sorting that throws.
    final merged = [...await _mergeWithRemote(local)];

    merged.sort((a, b) {
      final at = a.unit.lastInspection;
      final bt = b.unit.lastInspection;
      if (at == null && bt == null) return a.unit.name.compareTo(b.unit.name);
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return merged.map((e) => e.unit).toList(growable: false);
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

  // ---------------------------------------------------------------------------
  // Local derivation
  // ---------------------------------------------------------------------------

  List<_KeyedUnit> _deriveFromInspections() {
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

    final units = <_KeyedUnit>[];
    for (final entry in grouped.entries) {
      final history = entry.value
        ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
      final latest = history.first;
      final np = nameplates[latest.id];

      final make = _pick(np?.generatorMfr, latest.generatorMake);
      final model = _pick(np?.generatorModel, latest.generatorModel);

      units.add(
        _KeyedUnit(
          identityKey: entry.key,
          unit: EquipmentEntity(
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
            serialNumber: _pick(np?.generatorSn, latest.generatorSerial),
            voltage: _pick(np?.volts, latest.voltageRating),
            location: latest.address.trim().isNotEmpty
                ? latest.address
                : latest.siteCode,
            siteCode: latest.siteCode,
            siteGrade: latest.siteGrade,
            lastInspection: latest.serviceDate,
            inspectionCount: history.length,
            status: _statusFor(latest),
          ),
        ),
      );
    }

    return units;
  }

  // ---------------------------------------------------------------------------
  // Remote merge + publish
  // ---------------------------------------------------------------------------

  /// Merge remote rows in, keyed by identity. Locally derived units win: this
  /// device just read the inspection, the server copy may be older.
  Future<List<_KeyedUnit>> _mergeWithRemote(List<_KeyedUnit> local) async {
    final remote = _remote;
    if (remote == null) return local;

    final byKey = {for (final u in local) u.identityKey: u};

    try {
      for (final row in await remote.list()) {
        if (row.identityKey.isEmpty) continue;
        if (byKey.containsKey(row.identityKey)) continue; // local wins
        byKey[row.identityKey] = _KeyedUnit(
          identityKey: row.identityKey,
          unit: equipmentFromSupabaseJson(row.raw),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Equipment] remote merge failed (local only): $e');
      }
    }

    return byKey.values.toList();
  }

  /// Queue an upsert per derived unit so the shared registry stays current.
  Future<void> _publish(List<_KeyedUnit> units) async {
    final tenantId = SyncContext.tenantId;
    // Without a tenant the row would be rejected by RLS; don't queue writes
    // that are guaranteed to fail.
    if (tenantId == null || units.isEmpty) return;

    for (final u in units) {
      try {
        final id = equipmentIdFor(
          tenantId: tenantId,
          identityKey: u.identityKey,
        );
        await SyncService.instance.enqueueUpsert(
          table: kEquipmentTable,
          id: id,
          payload: equipmentToSupabaseJson(
            u.unit,
            identityKey: u.identityKey,
            tenantId: tenantId,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Equipment] could not queue upsert: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
  /// state only arrives from a manually maintained remote row.
  static EquipmentStatus _statusFor(Inspection latest) {
    final grade = latest.siteGrade.trim().toLowerCase();
    if (grade == 'red' || grade == 'amber' || latest.deficienciesDocumented) {
      return EquipmentStatus.maintenance;
    }
    return EquipmentStatus.active;
  }
}

/// A unit alongside the identity key it merges on.
@immutable
class _KeyedUnit {
  const _KeyedUnit({required this.identityKey, required this.unit});

  final String identityKey;
  final EquipmentEntity unit;
}

/// Repository provider for the equipment registry.
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepositoryImpl(
    remote: ref.watch(equipmentRemoteDatasourceProvider),
  );
});
