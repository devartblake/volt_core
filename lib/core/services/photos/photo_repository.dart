import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'photo_attachment.dart';

/// Adapter-free persistence for [PhotoAttachment] metadata.
///
/// Uses a plain `Box<String>` of JSON keyed by photo id — no Hive
/// TypeAdapter / code generation, mirroring the sync queue.
class PhotoRepository {
  PhotoRepository._();

  static final PhotoRepository instance = PhotoRepository._();

  static const String boxName = 'photo_attachments';

  Box<String>? _box;

  Future<Box<String>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) return existing;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
    } else {
      _box = await Hive.openBox<String>(boxName);
    }
    return _box!;
  }

  Future<void> init() async {
    await _ensureBox();
  }

  Future<void> put(PhotoAttachment photo) async {
    final box = await _ensureBox();
    await box.put(photo.id, photo.toJson());
  }

  /// Photos for a given owner, oldest first.
  Future<List<PhotoAttachment>> forOwner(
    String ownerType,
    String ownerId,
  ) async {
    final box = await _ensureBox();
    final list = <PhotoAttachment>[];
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final photo = PhotoAttachment.fromJson(raw);
        if (photo.ownerType == ownerType && photo.ownerId == ownerId) {
          list.add(photo);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PhotoRepo] Dropping unreadable $key: $e');
        await box.delete(key);
      }
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<PhotoAttachment?> getById(String id) async {
    final box = await _ensureBox();
    final raw = box.get(id);
    if (raw == null) return null;
    try {
      return PhotoAttachment.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    final box = await _ensureBox();
    await box.delete(id);
  }
}
