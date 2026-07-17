import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../storage/file_storage_service.dart';
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
    final dir = await FileStorageService.instance
        .getOwnerPhotosDirectory(ownerType, ownerId);
    final id = _uuid.v4();
    final ext = _normalizeExt(extension);
    final fileName = '$id.$ext';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    final ownerSegment = ownerId.isEmpty ? 'unassigned' : ownerId;
    final remotePath = 'photos/$ownerType/$ownerSegment/$fileName';

    final photo = PhotoAttachment(
      id: id,
      ownerType: ownerType,
      ownerId: ownerId,
      localPath: file.path,
      remotePath: remotePath,
      caption: caption,
      sizeBytes: bytes.length,
    );
    await PhotoRepository.instance.put(photo);

    // Best-effort cloud backup — never break the local save.
    try {
      await SyncService.instance.enqueueFileUpload(
        localPath: file.path,
        remotePath: remotePath,
        contentType: _contentTypeFor(ext),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PhotoService] backup enqueue failed: $e');
    }

    return photo;
  }

  Future<void> updateCaption(String id, String caption) async {
    final photo = await PhotoRepository.instance.getById(id);
    if (photo == null) return;
    await PhotoRepository.instance.put(photo.copyWith(caption: caption));
  }

  /// Delete the local image file and its metadata. A cloud backup, if already
  /// uploaded, is left intact.
  Future<void> deletePhoto(PhotoAttachment photo) async {
    try {
      final f = File(photo.localPath);
      if (await f.exists()) await f.delete();
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
