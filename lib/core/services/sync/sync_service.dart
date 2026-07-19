import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../connectivity/connectivity_service.dart';
import '../storage/web_file_store.dart';
import 'file_backup_service.dart';
import 'sync_context.dart';
import 'sync_operation.dart';
import 'sync_queue.dart';

/// High-level state of the sync layer, surfaced to the UI.
enum SyncState { idle, syncing, offline }

/// Immutable snapshot of sync progress for the UI.
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

/// Offline-first sync orchestrator.
///
/// Repositories enqueue [SyncOperation]s (they never block on the network);
/// this service drains the queue to Supabase whenever connectivity allows,
/// with exponential backoff and a bounded retry budget. Records go to Postgres
/// tables; files go to Supabase Storage.
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final SyncQueue _queue = SyncQueue.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final Uuid _uuid = const Uuid();

  /// Observable status for the UI (via [ValueListenableBuilder] or a provider).
  final ValueNotifier<SyncStatus> status =
      ValueNotifier<SyncStatus>(SyncStatus.initial);

  StreamSubscription<bool>? _connSub;
  bool _draining = false;
  DateTime? _lastSyncedAt;

  /// Give up automatic retries after this many attempts (op is kept as failed).
  static const int _maxAttempts = 8;

  /// Set up the queue + connectivity listener and kick off an initial drain.
  /// Never throws — sync must not be able to break app startup.
  Future<void> init() async {
    try {
      await _queue.init();
      await _connectivity.init();

      _connSub ??= _connectivity.onStatusChange.listen((online) {
        if (online) {
          if (kDebugMode) {
            debugPrint('[Sync] Connectivity restored → draining queue');
          }
          unawaited(sync());
        } else {
          _emit(state: SyncState.offline);
        }
      });

      await _refreshCounts();
      unawaited(sync());
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

  // ---------------------------------------------------------------------------
  // Enqueue API (called by repositories / save choke points)
  // ---------------------------------------------------------------------------

  /// Queue an insert-or-update of [payload] into Supabase table [table].
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

  /// Queue a delete of row [id] from Supabase table [table].
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

  /// Queue an upload of a local file to Supabase Storage at [remotePath].
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

  /// Queue an upload of bytes stored in [WebFileStore] (web platforms, where
  /// there is no local filesystem). [storePath] is the WebFileStore key.
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
    unawaited(sync());
  }

  // ---------------------------------------------------------------------------
  // Draining
  // ---------------------------------------------------------------------------

  /// Attempt to flush the queue. Re-entrant calls are ignored while a drain is
  /// already running. Never throws.
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
        // Supabase not initialised yet; leave everything queued.
        _emit(state: SyncState.idle);
        return;
      }

      _emit(state: SyncState.syncing);

      final ops = await _queue.all();
      for (final op in ops) {
        if (op.status == SyncOpStatus.failed && op.attempts >= _maxAttempts) {
          continue; // dead-lettered; awaits manual retryFailed()
        }
        if (op.attempts > 0 && !_backoffElapsed(op)) {
          continue; // still cooling down after a recent failure
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
                '[Sync] ${op.type.name} failed (attempt ${op.attempts}): $e');
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

  /// Exponential backoff capped at 5 minutes between retries of one op.
  bool _backoffElapsed(SyncOperation op) {
    final exp = op.attempts.clamp(0, 8);
    final delaySeconds = (1 << exp).clamp(1, 300);
    return DateTime.now().isAfter(
      op.updatedAt.add(Duration(seconds: delaySeconds)),
    );
  }

  /// Identity columns that are `uuid` in Postgres. An empty string is never a
  /// valid uuid, so we must omit these rather than send '' (which triggers
  /// `invalid input syntax for type uuid: ""`).
  static const Set<String> _uuidKeys = {
    'id',
    'tenant_id',
    'job_id',
    'site_id',
    'inspection_id',
    'created_by',
    'updated_by',
    'assigned_technician_user_id',
    'assigned_to_user_id',
    'source_id',
  };

  bool _isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty);

  Future<void> _dispatch(SupabaseClient client, SyncOperation op) async {
    switch (op.type) {
      case SyncOpType.upsert:
        final table = op.payload['table'] as String;
        final row = (op.payload['row'] as Map).cast<String, dynamic>()
          ..removeWhere((_, v) => v == null || v == '');

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
          // Stored bytes are gone (cleared storage) — drop, don't retry.
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

  /// Reset all dead-lettered ops back to pending and drain again.
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
