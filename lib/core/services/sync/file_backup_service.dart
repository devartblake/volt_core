import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a queued upload can't proceed but should NOT be retried
/// (e.g. the local file no longer exists). The sync layer drops these ops.
class FileBackupSkip implements Exception {
  const FileBackupSkip(this.reason);
  final String reason;

  @override
  String toString() => 'FileBackupSkip: $reason';
}

/// Uploads generated documents (PDFs) and signature images to Supabase Storage
/// so a lost or replaced device doesn't mean lost compliance records.
///
/// Uploads are driven through the sync queue ([SyncService]); this class only
/// performs the actual transfer and is safe to call directly for a one-off.
class FileBackupService {
  FileBackupService._();

  static final FileBackupService instance = FileBackupService._();

  /// Storage bucket name. Override via `SUPABASE_STORAGE_BUCKET` in the env
  /// file. The bucket must exist in the Supabase project.
  static String get bucket =>
      (dotenv.env['SUPABASE_STORAGE_BUCKET'] ?? '').isNotEmpty
          ? dotenv.env['SUPABASE_STORAGE_BUCKET']!
          : 'voltcore-files';

  SupabaseClient get _client => Supabase.instance.client;

  /// Upload the bytes of [localPath] to [remotePath] within [bucket].
  ///
  /// Returns the stored object path on success. Throws [FileBackupSkip] if the
  /// local file is gone (op should be dropped), or rethrows transport errors
  /// (op should be retried).
  Future<String> uploadFile({
    required String localPath,
    required String remotePath,
    String contentType = 'application/octet-stream',
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const FileBackupSkip('local file missing');
    }

    return uploadBytes(
      bytes: await file.readAsBytes(),
      remotePath: remotePath,
      contentType: contentType,
    );
  }

  /// Upload in-memory [bytes] to [remotePath] within [bucket]. Used directly
  /// on web, where there is no local filesystem.
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String remotePath,
    String contentType = 'application/octet-stream',
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          remotePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    if (kDebugMode) {
      debugPrint('[FileBackup] Uploaded $remotePath (${bytes.length} bytes)');
    }
    return remotePath;
  }
}
