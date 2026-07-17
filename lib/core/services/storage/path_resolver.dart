import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_storage_service.dart';

/// Re-anchors stored file paths to the *current* app-data root.
///
/// iOS changes the app's container path on every update/reinstall (the UUID in
/// `/var/mobile/.../Application/<UUID>/...` changes), so an absolute path saved
/// by a previous install no longer resolves. Rather than migrate the stored
/// data, we self-heal at read time: if the stored file is missing, rebuild the
/// path under the current root by locating a known managed subtree
/// (`pdfs/`, `signatures/`, `photos/`, `exports/`).
class PathResolver {
  const PathResolver._();

  /// Managed subtree markers we can re-anchor on. Order-independent; the first
  /// one found in the path wins.
  static const List<String> markers = [
    'pdfs',
    'signatures',
    'photos',
    'exports',
  ];

  /// Async resolve. Returns the stored path if it already exists or can't be
  /// re-anchored; otherwise the rebuilt path under the current root.
  static Future<String> resolve(String storedPath) async {
    if (storedPath.isEmpty) return storedPath;
    if (File(storedPath).existsSync()) return storedPath;

    final rel = relativeUnderMarker(storedPath);
    if (rel == null) return storedPath;

    final root = await FileStorageService.instance.getAppDataDirectory();
    return p.join(root.path, rel);
  }

  /// Synchronous resolve using the app-data root cached at startup. Falls back
  /// to the stored path if the root isn't cached yet or can't be re-anchored.
  static String resolveSync(String storedPath) {
    if (storedPath.isEmpty) return storedPath;
    if (File(storedPath).existsSync()) return storedPath;

    final root = FileStorageService.instance.cachedAppDataPath;
    if (root == null) return storedPath;

    final rel = relativeUnderMarker(storedPath);
    if (rel == null) return storedPath;

    return p.join(root, rel);
  }

  /// Resolve to a [File], or null if it still doesn't exist after re-anchoring.
  static Future<File?> resolveFile(String storedPath) async {
    if (storedPath.isEmpty) return null;
    final resolved = await resolve(storedPath);
    final f = File(resolved);
    return f.existsSync() ? f : null;
  }

  /// The portion of [storedPath] from the first managed marker segment onward
  /// (e.g. `pdfs/inspections/SITE/inspection_x.pdf`), or null if no marker is
  /// present. Handles both `/` and `\` separators.
  static String? relativeUnderMarker(String storedPath) {
    final segments = storedPath.replaceAll('\\', '/').split('/');
    for (var i = 0; i < segments.length; i++) {
      if (markers.contains(segments[i])) {
        return segments.sublist(i).join('/');
      }
    }
    return null;
  }
}
