import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../domain/material_item.dart';
import '../domain/profile_change.dart';
import 'materials_repository.dart';

const String kProfileChangeRequestsTable = 'profile_change_requests';

typedef ProfileChangesUpsert = Future<void> Function(
  String table,
  String id,
  Map<String, dynamic> row,
);
typedef ProfileChangesFetch = Future<List<Map<String, dynamic>>> Function(
  String table,
);

/// Proposed changes to generator parts profiles, kept on the device and queued
/// for the cloud. A plain `Box<String>` of JSON keyed by request id, like the
/// other materials stores, so no Hive adapter is involved.
class ProfileChangesRepository {
  ProfileChangesRepository({
    Box<String>? box,
    ProfileChangesUpsert? upsert,
    ProfileChangesFetch? fetch,
    String? Function()? tenantId,
    String? Function()? userId,
    String Function()? newId,
    DateTime Function()? now,
  })  : _injected = box,
        _upsert = upsert ?? _defaultUpsert,
        _fetch = fetch ?? _defaultFetch,
        _tenantId = tenantId ?? (() => SyncContext.tenantId),
        _userId = userId ?? (() => SyncContext.userId),
        _newId = newId ?? (() => const Uuid().v4()),
        _now = now ?? (() => DateTime.now().toUtc());

  static const String boxName = 'profile_change_requests';

  final Box<String>? _injected;
  final ProfileChangesUpsert _upsert;
  final ProfileChangesFetch _fetch;
  final String? Function() _tenantId;
  final String? Function() _userId;
  final String Function() _newId;
  final DateTime Function() _now;

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

  static Future<List<Map<String, dynamic>>> _defaultFetch(String table) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select()
          .timeout(const Duration(seconds: 8));
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Every request on the device, newest first.
  Future<List<ProfileChangeRequest>> all() async {
    final box = await _box();
    final list = [
      for (final raw in box.values)
        if (ProfileChangeRequest.decode(raw) case final r?) r,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Requests waiting for a reviewer, newest first.
  Future<List<ProfileChangeRequest>> pending() async =>
      [for (final r in await all()) if (r.isPending) r];

  /// Requests for one generator's profile.
  Future<List<ProfileChangeRequest>> forGenerator(
    String generatorKey, {
    bool pendingOnly = false,
  }) async =>
      [
        for (final r in await all())
          if (r.generatorKey == generatorKey && (!pendingOnly || r.isPending))
            r,
      ];

  Future<ProfileChangeRequest?> byId(String id) async {
    final box = await _box();
    return ProfileChangeRequest.decode(box.get(id));
  }

  Future<void> _store(ProfileChangeRequest r) async {
    final box = await _box();
    await box.put(r.id, ProfileChangeRequest.encode(r));
    final tenant = _tenantId();
    // No tenant means no signed-in session to tag the row with; it stays on
    // the device.
    if (tenant != null && tenant.isNotEmpty) {
      await _upsert(kProfileChangeRequestsTable, r.id,
          profileChangeToRow(r, tenant));
    }
  }

  /// Saves a request for the changes that turn [current] into [proposed].
  /// Throws [ArgumentError] when [note] is blank or nothing differs. The
  /// profile itself is not touched.
  Future<ProfileChangeRequest> propose({
    required String generatorKey,
    required List<MaterialItem> current,
    required List<MaterialItem> proposed,
    required String note,
    String make = '',
    String model = '',
    String serial = '',
    String proposedByName = '',
  }) async {
    if (note.trim().isEmpty) {
      throw ArgumentError('Say why the profile should change.');
    }
    final changes = ProfileChanges.diffProfiles(current, proposed);
    if (changes.isEmpty) {
      throw ArgumentError('Nothing is different from the profile.');
    }
    final now = _now();
    final r = ProfileChangeRequest(
      id: _newId(),
      generatorKey: generatorKey,
      make: make,
      model: model,
      serial: serial,
      proposedBy: _userId() ?? '',
      proposedByName: proposedByName,
      createdAt: now,
      updatedAt: now,
      note: note.trim(),
      changes: changes,
    );
    await _store(r);
    return r;
  }

  /// The proposer takes back a request that is still waiting.
  Future<ProfileChangeRequest?> withdraw(String id) async {
    final r = await byId(id);
    if (r == null || !r.isPending) return r;
    final next = r.copyWith(
        status: ProfileRequestStatus.withdrawn, updatedAt: _now());
    await _store(next);
    return next;
  }

  /// A reviewer turns a request down; the profile stays as it is.
  Future<ProfileChangeRequest?> reject(String id, {String note = ''}) async {
    final r = await byId(id);
    if (r == null || !r.isPending) return r;
    final now = _now();
    final next = r.copyWith(
      status: ProfileRequestStatus.rejected,
      reviewedBy: _userId(),
      reviewedAt: now,
      reviewNote: note.trim(),
      updatedAt: now,
    );
    await _store(next);
    return next;
  }

  /// A reviewer applies a request to the profile through [materials] (so the
  /// normal sync happens) and marks it approved.
  ///
  /// [only] limits it to those changes (item ids); stale changes are left out
  /// unless [includeStale]. When nothing could be applied the request is left
  /// pending so the reviewer can look again.
  Future<ApplyResult> approve(
    String id, {
    required MaterialsRepository materials,
    Set<String>? only,
    bool includeStale = false,
    String note = '',
  }) async {
    final r = await byId(id);
    if (r == null || !r.isPending) {
      return const ApplyResult(
          items: [], applied: [], skippedStale: [], alreadyApplied: []);
    }
    final owner = MaterialOwner.generator(
      key: r.generatorKey,
      make: r.make,
      model: r.model,
      serial: r.serial,
    );
    final current = await materials.load(owner);
    final result = ProfileChanges.applyChanges(current, r.changes,
        only: only, includeStale: includeStale);
    if (result.applied.isEmpty && result.alreadyApplied.isEmpty) return result;

    if (result.applied.isNotEmpty) await materials.save(owner, result.items);
    final now = _now();
    await _store(r.copyWith(
      status: ProfileRequestStatus.approved,
      reviewedBy: _userId(),
      reviewedAt: now,
      reviewNote: note.trim(),
      updatedAt: now,
    ));
    return result;
  }

  /// Pulls the cloud's requests into the device (reviewers see everyone's,
  /// technicians their own) keeping whichever copy is newer. Returns how many
  /// changed.
  Future<int> refreshFromCloud() async {
    var changed = 0;
    final box = await _box();
    for (final row in await _fetch(kProfileChangeRequestsTable)) {
      final remote = profileChangeFromRow(row);
      if (remote == null) continue;
      final local = ProfileChangeRequest.decode(box.get(remote.id));
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await box.put(remote.id, ProfileChangeRequest.encode(remote));
        changed++;
      }
    }
    return changed;
  }
}

// ---- row mapping ---------------------------------------------------------

Map<String, dynamic> profileChangeToRow(
  ProfileChangeRequest r,
  String tenantId,
) =>
    {
      'id': r.id,
      'tenant_id': tenantId,
      'equipment_key': r.generatorKey,
      'make': r.make,
      'model': r.model,
      'serial_number': r.serial,
      'proposed_by': r.proposedBy,
      'proposed_by_name': r.proposedByName,
      'note': r.note,
      'status': r.status.wire,
      'changes': [for (final c in r.changes) c.toJson()],
      'reviewed_by': r.reviewedBy,
      'reviewed_at': r.reviewedAt?.toUtc().toIso8601String(),
      'review_note': r.reviewNote,
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'updated_at': r.updatedAt.toUtc().toIso8601String(),
    };

ProfileChangeRequest? profileChangeFromRow(Map<String, dynamic> row) =>
    ProfileChangeRequest.fromJson({
      'id': row['id'],
      'generatorKey': row['equipment_key'],
      'make': row['make'],
      'model': row['model'],
      'serial': row['serial_number'],
      'proposedBy': row['proposed_by'],
      'proposedByName': row['proposed_by_name'],
      'note': row['note'],
      'status': row['status'],
      'changes': row['changes'],
      'reviewedBy': row['reviewed_by'],
      'reviewedAt': row['reviewed_at'],
      'reviewNote': row['review_note'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    });

final profileChangesRepositoryProvider =
    Provider<ProfileChangesRepository>((ref) => ProfileChangesRepository());

/// Every request on the device, newest first. Invalidate after a change.
final profileChangeRequestsProvider =
    FutureProvider.autoDispose<List<ProfileChangeRequest>>(
  (ref) => ref.watch(profileChangesRepositoryProvider).all(),
);

/// How many requests are waiting for a reviewer.
final pendingProfileChangeCountProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      (await ref.watch(profileChangesRepositoryProvider).pending()).length,
);
