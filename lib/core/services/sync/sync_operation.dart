import 'dart:convert';

/// The kind of work a queued [SyncOperation] represents.
enum SyncOpType {
  /// Insert-or-update a row in a Supabase table.
  upsert,

  /// Delete a row from a Supabase table by id.
  delete,

  /// Upload a local file's bytes to Supabase Storage (native platforms).
  fileUpload,

  /// Upload bytes held in [WebFileStore] to Supabase Storage (web).
  bytesUpload,
}

/// Lifecycle status of a queued operation.
enum SyncOpStatus {
  /// Waiting to be sent (or eligible for retry after backoff).
  pending,

  /// Exceeded the retry budget; kept for visibility / manual retry.
  failed,
}

/// A single unit of work in the offline sync outbox.
///
/// Operations are persisted as JSON strings in a plain Hive `Box<String>`,
/// so no Hive [TypeAdapter] / code generation is required.
class SyncOperation {
  SyncOperation({
    required this.id,
    required this.type,
    required this.entityId,
    required this.payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.attempts = 0,
    this.lastError,
    this.status = SyncOpStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Unique id; also used as the Hive key for this op.
  final String id;

  final SyncOpType type;

  /// Logical target ("table/recordId" for rows, remote path for files).
  /// Used to collapse repeated edits into a single pending op.
  final String entityId;

  /// Operation body. Shape depends on [type]:
  /// - upsert:     `{ 'table': String, 'row': Map }`
  /// - delete:     `{ 'table': String, 'id': String }`
  /// - fileUpload: `{ 'localPath': String, 'remotePath': String, 'contentType': String }`
  final Map<String, dynamic> payload;

  final DateTime createdAt;
  DateTime updatedAt;
  int attempts;
  String? lastError;
  SyncOpStatus status;

  /// Deterministic key so repeated edits to the same entity collapse into one
  /// queued op (latest payload wins) instead of growing without bound.
  String get dedupKey => '${type.name}:$entityId';

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'entityId': entityId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
        'status': status.name,
      };

  factory SyncOperation.fromMap(Map<String, dynamic> map) => SyncOperation(
        id: map['id'] as String,
        type: SyncOpType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => SyncOpType.upsert,
        ),
        entityId: map['entityId'] as String? ?? '',
        payload: (map['payload'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
        attempts: (map['attempts'] as num?)?.toInt() ?? 0,
        lastError: map['lastError'] as String?,
        status: SyncOpStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => SyncOpStatus.pending,
        ),
      );

  String toJson() => jsonEncode(toMap());

  factory SyncOperation.fromJson(String source) =>
      SyncOperation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
