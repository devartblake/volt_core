import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../connectivity/connectivity_service.dart';
import '../settings/app_preferences_service.dart';
import '../storage/web_file_store.dart';
import 'file_backup_service.dart';
import 'sync_context.dart';
import 'sync_operation.dart';
import 'sync_queue.dart';
import 'tenant_retag.dart';

enum SyncState { idle, syncing, offline }

@immutable
class SyncStatus {
  const SyncStatus({
    required this.state,
    required this.pending,
    required this.failed,
    this.lastSyncedAt,
  });

  final SyncState state;
  final int pending;
  final int failed;
  final DateTime? lastSyncedAt;

  bool get hasPendingWork => pending > 0 || failed > 0;

  static const SyncStatus initial =
      SyncStatus(state: SyncState.idle, pending: 0, failed: 0);

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    int? failed,
    DateTime? lastSyncedAt,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final SyncQueue _queue = SyncQueue.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final Uuid _uuid = const Uuid();

  final ValueNotifier<SyncStatus> status =
      ValueNotifier<SyncStatus>(SyncStatus.initial);

  StreamSubscription<bool>? _connSub;
  bool _draining = false;
  DateTime? _lastSyncedAt;

  static const int _maxAttempts = 8;

  bool get _autoSyncEnabled => AppPreferencesService.instance.autoSyncEnabled;

  Future<void> init() async {
    try {
      await _queue.init();
      await _connectivity.init();

      _connSub ??= _connectivity.onStatusChange.listen((online) {
        if (online) {
          if (_autoSyncEnabled) {
            if (kDebugMode) {
              debugPrint('[Sync] Connectivity restored → draining queue');
            }
            unawaited(sync());
          } else if (kDebugMode) {
            debugPrint('[Sync] Connectivity restored; auto-sync is disabled');
          }
        } else {
          _emit(state: SyncState.offline);
        }
      });

      await _refreshCounts();
      if (_autoSyncEnabled) unawaited(sync());
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] init failed (non-fatal): $e');
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Queue one immutable row for INSERT-only delivery.
  ///
  /// This is intentionally separate from [enqueueUpsert]. Append-only evidence
  /// tables can keep UPDATE revoked while still participating in the durable
  /// offline outbox. A duplicate primary key is treated as an idempotent
  /// success when the operation is dispatched.
  Future<void> enqueueInsert({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    if (table.isEmpty || id.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('[Sync] Skipping insert enqueue with empty table/id ($table)');
      }
      return;
    }
    await _queue.enqueue(SyncOperation(
      id: _uuid.v4(),
      type: SyncOpType.insert,
      entityId: '$table/$id',
      payload: {'table': table, 'row': payload},
    ));
    await _afterEnqueue();
  }

  Future<void> enqueueUpsert({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    if (table.isEmpty || id.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('[Sync] Skipping upsert enqueue with empty table/id ($table)');
      }
      return;
    }
    await _queue.enqueue(SyncOperation(
      id: _uuid.v4(),
      type: SyncOpType.upsert,
      entityId: '$table/$id',
      payload: {'table': table, 'row': payload},
    ));
    await _afterEnqueue();
  }

  Future<void> enqueueDelete({
    required String table,
    required String id,
  }) async {
    if (table.isEmpty || id.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('[Sync] Skipping delete enqueue with empty table/id ($table)');
      }
      return;
    }
    await _queue.enqueue(SyncOperation(
      id: _uuid.v4(),
      type: SyncOpType.delete,
      entityId: '$table/$id',
      payload: {'table': table, 'id': id},
    ));
    await _afterEnqueue();
  }

  Future<void> enqueueFileUpload({
    required String localPath,
    required String remotePath,
    String contentType = 'application/octet-stream',
  }) async {
    await _queue.enqueue(SyncOperation(
      id: _uuid.v4(),
      type: SyncOpType.fileUpload,
      entityId: remotePath,
      payload: {
        'localPath': localPath,
        'remotePath': remotePath,
        'contentType': contentType,
      },
    ));
    await _afterEnqueue();
  }

  Future<void> enqueueBytesUpload({
    required String storePath,
    required String remotePath,
    String contentType = 'application/octet-stream',
  }) async {
    await _queue.enqueue(SyncOperation(
      id: _uuid.v4(),
      type: SyncOpType.bytesUpload,
      entityId: remotePath,
      payload: {
        'storePath': storePath,
        'remotePath': remotePath,
        'contentType': contentType,
      },
    ));
    await _afterEnqueue();
  }

  Future<void> _afterEnqueue() async {
    await _refreshCounts();
    if (_autoSyncEnabled) unawaited(sync());
  }

  /// Manual sync always attempts a drain, even when automatic sync is disabled.
  Future<void> sync() async {
    if (_draining) return;
    _draining = true;
    try {
      final online = await _connectivity.isOnline();
      if (!online) {
        _emit(state: SyncState.offline);
        return;
      }

      final client = _client;
      if (client == null) {
        _emit(state: SyncState.idle);
        return;
      }

      _emit(state: SyncState.syncing);

      final ops = await _queue.all();
      await _retagQueuedRows(ops);
      for (final op in ops) {
        if (op.status == SyncOpStatus.failed && op.attempts >= _maxAttempts) {
          continue;
        }
        if (op.attempts > 0 && !_backoffElapsed(op)) {
          continue;
        }

        try {
          await _dispatch(client, op);
          await _queue.remove(op.id);
        } on FileBackupSkip catch (e) {
          if (kDebugMode) debugPrint('[Sync] Dropping op ${op.id}: $e');
          await _queue.remove(op.id);
        } catch (e) {
          op.attempts += 1;
          op.updatedAt = DateTime.now();
          op.lastError = e.toString();
          if (op.attempts >= _maxAttempts) op.status = SyncOpStatus.failed;
          await _queue.save(op);
          if (kDebugMode) {
            debugPrint(
              '[Sync] ${op.type.name} failed (attempt ${op.attempts}): $e',
            );
            _debugExplainIfRlsDenied(e, op);
          }
        }
      }

      _lastSyncedAt = DateTime.now();
      await _refreshCounts();
      _emit(state: SyncState.idle);
    } finally {
      _draining = false;
    }
  }

  /// Explain a 42501 in terms of the row that was actually rejected.
  static void _debugExplainIfRlsDenied(Object error, SyncOperation op) {
    if (!error.toString().contains('42501')) return;

    final row = op.type == SyncOpType.upsert || op.type == SyncOpType.insert
        ? op.payload['row']
        : null;
    final rowTenant = row is Map ? row['tenant_id']?.toString() : null;
    final tenant = SyncContext.tenantId;
    final user = SyncContext.userId;

    final offender = rowTenant ?? tenant;

    debugPrint(
      '[Sync] ^ This is row-level security, not connectivity. Retrying will '
      'not clear it.\n'
      '       tenant_id on the row = ${rowTenant ?? '(none on this op)'}\n'
      '       tenant_id configured = '
      '${tenant ?? '(SUPABASE_TENANT_ID not set)'}\n'
      '       auth user            = ${user ?? '(no session)'}\n'
      '${offender != null && offender == user ? '       The rejected tenant_id is the user id, not a tenant id.\n' : ''}'
      '${rowTenant != null && tenant != null && rowTenant != tenant ? '       The row predates the current setting; it is re-stamped and\n'
          '       retried automatically on the next drain.\n' : '       Fix: run supabase/manual/tenant_bootstrap.sql, then set\n'
          '       SUPABASE_TENANT_ID to the tenant id it prints and restart.\n'}',
    );
  }

  /// Bring queued rows up to date with the currently configured tenant.
  ///
  /// See [retagQueuedRow]: without this, fixing `SUPABASE_TENANT_ID` only
  /// affects rows queued afterwards, and everything already in the outbox
  /// retries against the old tenant until it exhausts its budget and dies.
  Future<void> _retagQueuedRows(List<SyncOperation> ops) async {
    final tenant = SyncContext.tenantId;
    if (tenant == null) return;

    var retagged = 0;
    for (final op in ops) {
      if (retagQueuedRow(op, tenant)) {
        await _queue.save(op);
        retagged++;
      }
    }

    if (retagged > 0 && kDebugMode) {
      debugPrint(
        '[Sync] Re-stamped $retagged queued row(s) onto tenant $tenant; they '
        'were captured under a different one.',
      );
    }
  }

  bool _backoffElapsed(SyncOperation op) {
    final exp = op.attempts.clamp(0, 8);
    final delaySeconds = (1 << exp).clamp(1, 300);
    return DateTime.now().isAfter(
      op.updatedAt.add(Duration(seconds: delaySeconds)),
    );
  }

  static const Set<String> _uuidKeys = {
    'id',
    'tenant_id',
    'job_id',
    'site_id',
    'inspection_id',
    'response_id',
    'created_by',
    'updated_by',
    'assigned_technician_user_id',
    'assigned_to_user_id',
    'source_id',
  };

  bool _isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty);

  Map<String, dynamic> _cleanRow(Map<dynamic, dynamic> value) =>
      value.cast<String, dynamic>()
        ..removeWhere(
          (k, v) => v == null || (_uuidKeys.contains(k) && _isBlank(v)),
        );

  Future<void> _dispatch(SupabaseClient client, SyncOperation op) async {
    switch (op.type) {
      case SyncOpType.insert:
        final table = op.payload['table'] as String;
        final row = _cleanRow(op.payload['row'] as Map);

        if (kDebugMode) {
          debugPrint('[Sync] Dispatching immutable insert to "$table":');
          debugPrint('       Row: $row');
          debugPrint('       User: ${SyncContext.userId}');
          debugPrint('       Tenant: ${SyncContext.tenantId}');
        }

        try {
          await client.from(table).insert(row);
        } on PostgrestException catch (error) {
          // A previous delivery may have succeeded even if the client did not
          // receive its response. Stable ids make a duplicate-key retry proof
          // of prior success, so remove the queued operation instead of turning
          // immutable evidence into an UPDATE-capable upsert.
          if (error.code != '23505') rethrow;
          if (kDebugMode) {
            debugPrint(
              '[Sync] Immutable insert already exists; treating as delivered.',
            );
          }
        }
        break;
      case SyncOpType.upsert:
        final table = op.payload['table'] as String;
        final row = _cleanRow(op.payload['row'] as Map);

        if (kDebugMode) {
          debugPrint('[Sync] Dispatching upsert to "$table":');
          debugPrint('       Row: $row');
          debugPrint('       User: ${SyncContext.userId}');
          debugPrint('       Tenant: ${SyncContext.tenantId}');
        }

        await client.from(table).upsert(row);
        break;
      case SyncOpType.delete:
        final table = op.payload['table'] as String;
        final id = op.payload['id'] as String?;
        if (_isBlank(id)) {
          if (kDebugMode) {
            debugPrint('[Sync] Dropping delete on "$table" with no valid id');
          }
          return;
        }
        await client.from(table).delete().eq('id', id!);
        break;
      case SyncOpType.fileUpload:
        await FileBackupService.instance.uploadFile(
          localPath: op.payload['localPath'] as String,
          remotePath: op.payload['remotePath'] as String,
          contentType:
              op.payload['contentType'] as String? ?? 'application/octet-stream',
        );
        break;
      case SyncOpType.bytesUpload:
        final bytes =
            WebFileStore.instance.getSync(op.payload['storePath'] as String);
        if (bytes == null) {
          throw const FileBackupSkip('stored bytes missing');
        }
        await FileBackupService.instance.uploadBytes(
          bytes: bytes,
          remotePath: op.payload['remotePath'] as String,
          contentType:
              op.payload['contentType'] as String? ?? 'application/octet-stream',
        );
        break;
    }
  }

  Future<void> retryFailed() async {
    final ops = await _queue.all();
    for (final op in ops) {
      if (op.status == SyncOpStatus.failed) {
        op.status = SyncOpStatus.pending;
        op.attempts = 0;
        op.updatedAt = DateTime.now();
        await _queue.save(op);
      }
    }
    await sync();
  }

  Future<void> _refreshCounts() async {
    final ops = await _queue.all();
    _emit(
      pending: ops.where((o) => o.status == SyncOpStatus.pending).length,
      failed: ops.where((o) => o.status == SyncOpStatus.failed).length,
    );
  }

  void _emit({SyncState? state, int? pending, int? failed}) {
    status.value = status.value.copyWith(
      state: state,
      pending: pending,
      failed: failed,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
  }
}
