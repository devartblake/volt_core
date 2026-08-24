import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

@immutable
class WebStoredFileInfo {
  const WebStoredFileInfo({
    required this.path,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final int sizeBytes;
  final DateTime modified;
}

/// Byte storage for platforms without a real filesystem (Flutter web).
///
/// dart:io and path_provider don't work on web, so signature PNGs, photos, and
/// generated PDFs are stored here instead: base64 in an adapter-free
/// `Box<String>` (backed by IndexedDB), keyed by the same logical path the
/// native side would use.
///
/// A second adapter-free box tracks modification timestamps so document-library
/// views can sort web-stored reports without inventing filesystem metadata.
class WebFileStore {
  WebFileStore._();

  static final WebFileStore instance = WebFileStore._();

  static const String boxName = 'web_files';
  static const String metadataBoxName = 'web_file_metadata';

  Box<String>? _box;
  Box<String>? _metadataBox;

  /// Open the backing boxes. Called at startup on web; harmless elsewhere.
  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<String>(boxName);
      } else {
        _box = await Hive.openBox<String>(boxName);
      }
    }

    if (_metadataBox == null || !_metadataBox!.isOpen) {
      if (Hive.isBoxOpen(metadataBoxName)) {
        _metadataBox = Hive.box<String>(metadataBoxName);
      } else {
        _metadataBox = await Hive.openBox<String>(metadataBoxName);
      }
    }
  }

  bool get isReady =>
      _box != null &&
      _box!.isOpen &&
      _metadataBox != null &&
      _metadataBox!.isOpen;

  Future<void> put(String logicalPath, Uint8List bytes) async {
    await init();
    await _box!.put(logicalPath, base64Encode(bytes));
    await _metadataBox!.put(logicalPath, DateTime.now().toUtc().toIso8601String());
    if (kDebugMode) {
      debugPrint('[WebFileStore] Stored $logicalPath (${bytes.length} bytes)');
    }
  }

  /// Synchronous read; returns null if the box isn't open or the key is
  /// missing/corrupt. Safe to call on native (where the box is never opened).
  Uint8List? getSync(String logicalPath) {
    final box = _box;
    if (box == null || !box.isOpen) return null;
    final raw = box.get(logicalPath);
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  bool existsSync(String logicalPath) {
    final box = _box;
    return box != null && box.isOpen && box.containsKey(logicalPath);
  }

  /// List byte entries whose logical path begins with [prefix].
  ///
  /// Existing entries created before metadata tracking use the Unix epoch as a
  /// stable fallback timestamp. New files always carry their actual write time.
  List<WebStoredFileInfo> listSync({String prefix = ''}) {
    final box = _box;
    if (box == null || !box.isOpen) return const [];
    final metadata = _metadataBox;
    final files = <WebStoredFileInfo>[];

    for (final key in box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final bytes = getSync(key);
      if (bytes == null) continue;

      DateTime modified = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (metadata != null && metadata.isOpen) {
        final rawModified = metadata.get(key);
        if (rawModified != null) {
          modified = DateTime.tryParse(rawModified)?.toUtc() ?? modified;
        }
      }

      files.add(
        WebStoredFileInfo(
          path: key,
          sizeBytes: bytes.length,
          modified: modified,
        ),
      );
    }

    files.sort((a, b) => b.modified.compareTo(a.modified));
    return List.unmodifiable(files);
  }

  Future<void> remove(String logicalPath) async {
    final box = _box;
    if (box == null || !box.isOpen) return;
    await box.delete(logicalPath);
    final metadata = _metadataBox;
    if (metadata != null && metadata.isOpen) {
      await metadata.delete(logicalPath);
    }
  }
}
