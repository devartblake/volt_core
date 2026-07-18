import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Byte storage for platforms without a real filesystem (Flutter web).
///
/// dart:io and path_provider don't work on web, so signature PNGs and photos
/// are stored here instead: base64 in an adapter-free `Box<String>` (backed by
/// IndexedDB), keyed by the same logical path the native side would use
/// (e.g. `signatures/inspections/x.png`, `photos/inspection/<id>/<uuid>.jpg`).
/// Those logical paths are what get persisted in records, and the cloud-backup
/// queue uploads from these bytes.
///
/// Reads are synchronous once the box is open (Hive keeps values in memory),
/// which lets synchronous consumers (PDF signature embedding) work too.
class WebFileStore {
  WebFileStore._();

  static final WebFileStore instance = WebFileStore._();

  static const String boxName = 'web_files';

  Box<String>? _box;

  /// Open the backing box. Called at startup on web; harmless elsewhere.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
    } else {
      _box = await Hive.openBox<String>(boxName);
    }
  }

  bool get isReady => _box != null && _box!.isOpen;

  Future<void> put(String logicalPath, Uint8List bytes) async {
    await init();
    await _box!.put(logicalPath, base64Encode(bytes));
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

  Future<void> remove(String logicalPath) async {
    final box = _box;
    if (box == null || !box.isOpen) return;
    await box.delete(logicalPath);
  }
}
