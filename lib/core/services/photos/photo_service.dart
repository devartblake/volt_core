import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../storage/file_storage_service.dart';
import '../storage/path_resolver.dart';
import '../storage/web_file_store.dart';
import '../sync/sync_service.dart';
import 'photo_attachment.dart';
import 'photo_repository.dart';

/// Facade that ties photo capture together with storage, metadata, and cloud
/// backup. Widgets talk to this rather than the pieces directly.
class PhotoService {
  PhotoService._();

  static final PhotoService instance = PhotoService._();

  final Uuid _uuid = const Uuid();

  Future<List<PhotoAttachment>> listForOwner(
    String ownerType,
    String ownerId,
  ) =>
      PhotoRepository.instance.forOwner(ownerType, ownerId);

  /// Persist [bytes] as a photo for the given owner, record its metadata, and
  /// queue it for cloud backup. Returns the created attachment.
  Future<PhotoAttachment> addPhoto({
    required String ownerType,
    required String ownerId,
    required Uint8List bytes,
    String extension = 'jpg',
    String caption = '',
  }) async {
    final id = _uuid.v4();
    final ext = _normalizeExt(extension);
    final fileName = '$id.$ext';
    final ownerSegment = ownerId.isEmpty ? 'unassigned' : ownerId;
    final remotePath = 'photos/$ownerType/$ownerSegment/$fileName';

    final String storedPath;
    if (kIsWeb) {
      // No filesystem on web — bytes live in WebFileStore (IndexedDB) under
      // the logical path, which is also what gets persisted on the record.
      storedPath = remotePath;
      await WebFileStore.instance.put(storedPath, bytes);
    } else {
      final dir = await FileStorageService.instance
          .getOwnerPhotosDirectory(ownerType, ownerId);
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      storedPath = file.path;
    }

    final photo = PhotoAttachment(
      id: id,
      ownerType: ownerType,
      ownerId: ownerId,
      localPath: storedPath,
      remotePath: remotePath,
      caption: caption,
      sizeBytes: bytes.length,
    );
    await PhotoRepository.instance.put(photo);

    // Best-effort cloud backup — never break the local save.
    try {
      if (kIsWeb) {
        await SyncService.instance.enqueueBytesUpload(
          storePath: storedPath,
          remotePath: remotePath,
          contentType: _contentTypeFor(ext),
        );
      } else {
        await SyncService.instance.enqueueFileUpload(
          localPath: storedPath,
          remotePath: remotePath,
          contentType: _contentTypeFor(ext),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] backup enqueue failed: $e');
    }

    return photo;
  }

  /// Read a photo's bytes on any platform: [WebFileStore] on web, the
  /// filesystem (with stale-path re-anchoring) on native. Null if missing.
  Future<Uint8List?> loadBytes(PhotoAttachment photo) async {
    final fromStore = WebFileStore.instance.getSync(photo.localPath);
    if (fromStore != null) return fromStore;
    if (kIsWeb) return null;
    final file = await PathResolver.resolveFile(photo.localPath);
    return file?.readAsBytes();
  }

  /// Synchronous variant for widget builds. Same sources as [loadBytes].
  Uint8List? loadBytesSync(PhotoAttachment photo) {
    final fromStore = WebFileStore.instance.getSync(photo.localPath);
    if (fromStore != null) return fromStore;
    if (kIsWeb) return null;
    try {
      final f = File(PathResolver.resolveSync(photo.localPath));
      if (f.existsSync()) return f.readAsBytesSync();
    } catch (_) {
      // fall through
    }
    return null;
  }

  Future<void> updateCaption(String id, String caption) async {
    final photo = await PhotoRepository.instance.getById(id);
    if (photo == null) return;
    await PhotoRepository.instance.put(photo.copyWith(caption: caption));
  }

  /// Delete the local image (file or web-store bytes) and its metadata. A
  /// cloud backup, if already uploaded, is left intact.
  Future<void> deletePhoto(PhotoAttachment photo) async {
    try {
      if (kIsWeb) {
        await WebFileStore.instance.remove(photo.localPath);
      } else {
        final f = File(photo.localPath);
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] delete file failed: $e');
    }
    await PhotoRepository.instance.remove(photo.id);
  }

  String _normalizeExt(String ext) {
    final cleaned = ext.replaceAll('.', '').toLowerCase().trim();
    return cleaned.isEmpty ? 'jpg' : cleaned;
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
