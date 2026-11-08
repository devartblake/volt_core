import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/sync/file_backup_service.dart';
import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../domain/catalog_part.dart';

/// Where a part's product photo lives in Storage: inside the existing backup
/// bucket, under a per-tenant prefix.
String partImageObjectPath(String tenantId, String partId) =>
    'part-images/$tenantId/$partId.jpg';

/// Loads, saves and removes product photos. Injectable so tests never touch
/// the disk or Supabase.
abstract class PartImageStore {
  /// The photo's bytes, from the device or (once) from Storage; null when the
  /// part has none or it can't be had. Never throws.
  Future<Uint8List?> load(CatalogPart part);

  /// Stores [bytes] for [part] (cached locally, queued for upload) and returns
  /// the object path to keep on the part. Throws when it can't be stored.
  Future<String> save(CatalogPart part, Uint8List bytes);

  /// Forgets the local copy. Never throws.
  Future<void> remove(CatalogPart part);
}

class StoragePartImageStore implements PartImageStore {
  StoragePartImageStore();

  Future<File> _file(String partId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'part_images', '$partId.jpg'));
  }

  @override
  Future<Uint8List?> load(CatalogPart part) async {
    final path = part.imagePath;
    if (path == null || path.isEmpty) return null;
    try {
      File? file;
      if (!kIsWeb) {
        file = await _file(part.id);
        if (await file.exists()) return await file.readAsBytes();
      }
      final bytes = await Supabase.instance.client.storage
          .from(FileBackupService.bucket)
          .download(path)
          .timeout(const Duration(seconds: 15));
      if (bytes.isEmpty) return null;
      if (file != null) {
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> save(CatalogPart part, Uint8List bytes) async {
    final tenant = SyncContext.tenantId;
    if (tenant == null || tenant.isEmpty) {
      throw StateError('Sign in to add a photo.');
    }
    final remote = partImageObjectPath(tenant, part.id);
    if (kIsWeb) {
      await FileBackupService.instance.uploadBytes(
        bytes: bytes,
        remotePath: remote,
        contentType: 'image/jpeg',
      );
      return remote;
    }
    final file = await _file(part.id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await SyncService.instance.enqueueFileUpload(
      localPath: file.path,
      remotePath: remote,
      contentType: 'image/jpeg',
    );
    return remote;
  }

  @override
  Future<void> remove(CatalogPart part) async {
    if (kIsWeb) return;
    try {
      final f = await _file(part.id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

final partImageStoreProvider =
    Provider<PartImageStore>((ref) => StoragePartImageStore());

enum PartImageSource { camera, gallery }

/// Picks a product photo, already shrunk (max 1024 px long edge, JPEG ~80).
abstract class PartImagePicker {
  Future<Uint8List?> pick(PartImageSource source);
}

class DevicePartImagePicker implements PartImagePicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(PartImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == PartImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    return picked?.readAsBytes();
  }
}

final partImagePickerProvider =
    Provider<PartImagePicker>((ref) => DevicePartImagePicker());
