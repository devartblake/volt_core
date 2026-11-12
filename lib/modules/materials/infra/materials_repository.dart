import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../domain/material_item.dart';
import '../domain/material_list.dart';

const String kAssetPartsTable = 'asset_parts';
const String kJobMaterialLinesTable = 'job_material_lines';

/// Who the items belong to, with what the cloud rows need to identify them.
class MaterialOwner {
  const MaterialOwner.generator({
    required this.key,
    this.make = '',
    this.model = '',
    this.serial = '',
  })  : type = MaterialOwnerType.generator,
        equipmentKey = key;

  const MaterialOwner.inspection({required String id, this.equipmentKey = ''})
      : type = MaterialOwnerType.inspection,
        key = id,
        make = '',
        model = '',
        serial = '';

  const MaterialOwner.maintenance({required String id, this.equipmentKey = ''})
      : type = MaterialOwnerType.maintenance,
        key = id,
        make = '',
        model = '',
        serial = '';

  final MaterialOwnerType type;

  /// The generator's profile key, or the job's id.
  final String key;

  /// For a job: the generator it was for (its profile key), if known.
  final String equipmentKey;
  final String make;
  final String model;
  final String serial;

  String get storeKey => '${type.wire}:$key';

  @override
  bool operator ==(Object other) =>
      other is MaterialOwner && other.storeKey == storeKey;

  @override
  int get hashCode => storeKey.hashCode;
}

typedef MaterialsUpsert = Future<void> Function(
  String table,
  String id,
  Map<String, dynamic> row,
);
typedef MaterialsDelete = Future<void> Function(String table, String id);

/// Parts on a generator's profile and on inspections / maintenance, kept on
/// the device and queued for the cloud.
///
/// Stored as a plain `Box<String>` of JSON keyed by owner, like vehicle
/// inspections, so no Hive adapter is involved and a record's materials are
/// read or replaced as one unit.
class MaterialsRepository {
  MaterialsRepository({
    Box<String>? box,
    MaterialsUpsert? upsert,
    MaterialsDelete? delete,
    String? Function()? tenantId,
  })  : _injected = box,
        _upsert = upsert ?? _defaultUpsert,
        _delete = delete ?? _defaultDelete,
        _tenantId = tenantId ?? (() => SyncContext.tenantId);

  static const String boxName = 'material_items';

  final Box<String>? _injected;
  final MaterialsUpsert _upsert;
  final MaterialsDelete _delete;
  final String? Function() _tenantId;

  Future<Box<String>> _box() async {
    final injected = _injected;
    if (injected != null) return injected;
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  static Future<void> _defaultUpsert(
    String table,
    String id,
    Map<String, dynamic> row,
  ) =>
      SyncService.instance.enqueueUpsert(table: table, id: id, payload: row);

  static Future<void> _defaultDelete(String table, String id) =>
      SyncService.instance.enqueueDelete(table: table, id: id);

  /// The items saved for [owner], in the order they were saved.
  Future<List<MaterialItem>> load(MaterialOwner owner) async {
    final box = await _box();
    return MaterialItem.decodeList(box.get(owner.storeKey));
  }

  /// Every inspection and maintenance list on the device, for planning what
  /// parts upcoming jobs need.
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async {
    final box = await _box();
    final out =
        <({MaterialOwnerType type, String id, List<MaterialItem> items})>[];
    for (final key in box.keys) {
      final k = key.toString();
      for (final type in [
        MaterialOwnerType.inspection,
        MaterialOwnerType.maintenance,
      ]) {
        final prefix = '${type.wire}:';
        if (!k.startsWith(prefix)) continue;
        final items = MaterialItem.decodeList(box.get(key));
        if (items.isNotEmpty) {
          out.add((type: type, id: k.substring(prefix.length), items: items));
        }
      }
    }
    return out;
  }

  /// Saves [items] for [owner]: blank items are dropped, the slot rules are
  /// applied, and what changed is queued for the cloud. Returns what was kept.
  Future<List<MaterialItem>> save(
    MaterialOwner owner,
    List<MaterialItem> items,
  ) async {
    final box = await _box();
    final previous = MaterialItem.decodeList(box.get(owner.storeKey));
    final kept = MaterialListOps.forSaving(items);

    await box.put(owner.storeKey, MaterialItem.encodeList(kept));
    await _sync(owner, previous, kept);
    return kept;
  }

  /// Local only: used by autosave so typing does not flood the sync queue.
  Future<void> saveDraft(MaterialOwner owner, List<MaterialItem> items) async {
    final box = await _box();
    await box.put(owner.storeKey, MaterialItem.encodeList(items));
  }

  Future<void> _sync(
    MaterialOwner owner,
    List<MaterialItem> before,
    List<MaterialItem> after,
  ) async {
    final tenant = _tenantId();
    // No tenant means no signed-in session to tag rows with; the items stay on
    // the device and the next save after signing in queues them.
    if (tenant == null || tenant.isEmpty) return;

    final table = owner.type == MaterialOwnerType.generator
        ? kAssetPartsTable
        : kJobMaterialLinesTable;

    final beforeById = {for (final i in before) i.id: jsonEncode(i.toJson())};
    for (var index = 0; index < after.length; index++) {
      final item = after[index];
      final same = beforeById[item.id] == jsonEncode(item.toJson());
      // Order can change without the item changing, so unchanged items are
      // only skipped when they were not in the saved list at all.
      if (same && before.indexWhere((b) => b.id == item.id) == index) continue;
      await _upsert(
        table,
        item.id,
        materialItemToRow(item, tenant, owner, sortOrder: index),
      );
    }

    final afterIds = {for (final i in after) i.id};
    for (final gone in before) {
      if (!afterIds.contains(gone.id)) await _delete(table, gone.id);
    }
  }
}

String _date(DateTime d) => d.toIso8601String().split('T').first;

/// The cloud row for one item.
Map<String, dynamic> materialItemToRow(
  MaterialItem item,
  String tenantId,
  MaterialOwner owner, {
  required int sortOrder,
}) {
  final common = <String, dynamic>{
    'id': item.id,
    'tenant_id': tenantId,
    'slot_type': item.slot.wire,
    'role': item.role.wire,
    'sort_order': sortOrder,
    'part_number': item.partNumber.trim(),
    'part_name': item.partName.trim(),
    'manufacturer': item.manufacturer.trim(),
    'quantity': item.quantity,
    'date_used': item.dateUsed == null ? null : _date(item.dateUsed!),
    'notes': item.notes.trim(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };

  if (owner.type == MaterialOwnerType.generator) {
    return {
      ...common,
      'equipment_key': owner.key,
      'make': owner.make,
      'model': owner.model,
      'serial_number': owner.serial,
    };
  }
  return {
    ...common,
    'job_type': owner.type.wire,
    'job_id': owner.key,
    'equipment_key': owner.equipmentKey,
    'needs_replacement': item.needsReplacement,
    'status': item.usedMovementId == null ? 'listed' : 'used',
    'used_movement_id': item.usedMovementId,
  };
}

final materialsRepositoryProvider =
    Provider<MaterialsRepository>((ref) => MaterialsRepository());

/// The saved items for an owner. Invalidate after a save elsewhere.
final materialItemsProvider = FutureProvider.autoDispose
    .family<List<MaterialItem>, MaterialOwner>(
  (ref, owner) => ref.watch(materialsRepositoryProvider).load(owner),
);
