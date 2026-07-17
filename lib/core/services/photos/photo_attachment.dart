import 'dart:convert';

/// Metadata for one photo attached to an inspection or maintenance record.
///
/// Persisted as JSON in a plain Hive `Box<String>` (adapter-free, no code
/// generation). The image bytes themselves live on disk under the managed
/// `photos/` tree and are backed up to Supabase Storage via the sync queue.
class PhotoAttachment {
  PhotoAttachment({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.localPath,
    this.remotePath,
    this.caption = '',
    this.sizeBytes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Owner types used across the app.
  static const String ownerInspection = 'inspection';
  static const String ownerMaintenance = 'maintenance';

  final String id;

  /// [ownerInspection] or [ownerMaintenance].
  final String ownerType;

  /// The inspection id or maintenance record id this photo belongs to.
  final String ownerId;

  final String localPath;

  /// Storage object path once (or if) uploaded.
  final String? remotePath;

  String caption;
  final int sizeBytes;
  final DateTime createdAt;

  PhotoAttachment copyWith({String? caption, String? remotePath}) =>
      PhotoAttachment(
        id: id,
        ownerType: ownerType,
        ownerId: ownerId,
        localPath: localPath,
        remotePath: remotePath ?? this.remotePath,
        caption: caption ?? this.caption,
        sizeBytes: sizeBytes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerType': ownerType,
        'ownerId': ownerId,
        'localPath': localPath,
        'remotePath': remotePath,
        'caption': caption,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhotoAttachment.fromMap(Map<String, dynamic> map) => PhotoAttachment(
        id: map['id'] as String,
        ownerType: map['ownerType'] as String? ?? '',
        ownerId: map['ownerId'] as String? ?? '',
        localPath: map['localPath'] as String? ?? '',
        remotePath: map['remotePath'] as String?,
        caption: map['caption'] as String? ?? '',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );

  String toJson() => jsonEncode(toMap());

  factory PhotoAttachment.fromJson(String source) =>
      PhotoAttachment.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
