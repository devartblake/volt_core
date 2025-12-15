import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Central file storage service that manages all file locations in the app.
///
/// Provides organized, platform-aware storage for:
/// - Hive database files
/// - Digital signatures
/// - Generated PDF reports
/// - Temporary files
/// - Cached data
///
/// **Windows-safe:** Uses AppData\Roaming instead of Documents to avoid
/// protected folder access issues.
///
/// Directory structure:
/// ```
/// Windows: C:\Users\[User]\AppData\Roaming\com.theoreticalmindstech.voltcore\
/// Android/iOS: [App Documents]/
///
/// ├── hive/                    # Hive database (managed by Hive)
/// ├── signatures/              # Digital signatures
/// │   ├── inspections/         # By inspection ID
/// │   └── maintenance/         # By job ID
/// ├── pdfs/                    # Generated PDF reports
/// │   ├── inspections/         # Inspection reports
/// │   └── maintenance/         # Maintenance reports
/// └── temp/                    # Temporary files
///
/// [App Cache]/
/// ├── images/                  # Cached images
/// └── downloads/               # Temporary downloads
/// ```
class FileStorageService {
  FileStorageService._();

  static final FileStorageService instance = FileStorageService._();

  // ============================================
  // Directory Names (Constants)
  // ============================================
  static const String _dirHive = 'hive';
  static const String _dirSignatures = 'signatures';
  static const String _dirPdfs = 'pdfs';
  static const String _dirTemp = 'temp';
  static const String _dirImages = 'images';
  static const String _dirDownloads = 'downloads';

  static const String _dirInspections = 'inspections';
  static const String _dirMaintenance = 'maintenance';

  // ============================================
  // Base Directories (Platform-Aware)
  // ============================================

  /// Get the app's persistent data directory
  ///
  /// **Windows:** AppData\Roaming (avoids Documents protected folders)
  /// **Mobile:** Application Documents Directory
  ///
  /// This is where persistent data is stored that should survive app updates.
  Future<Directory> getAppDataDirectory() async {
    // On Windows, use ApplicationSupport which maps to AppData\Roaming
    // This avoids the "My Music", "My Pictures" protected folder issues
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return await getApplicationSupportDirectory();
    }

    // On mobile, use documents directory
    return await getApplicationDocumentsDirectory();
  }

  /// Get the app's cache directory
  /// This is for temporary/cached data that can be deleted
  Future<Directory> getCacheDirectory() async {
    return await getApplicationCacheDirectory();
  }

  /// Get the app's support directory
  /// Platform-specific app data
  Future<Directory> getSupportDirectory() async {
    return await getApplicationSupportDirectory();
  }

  // ============================================
  // Hive Database Storage
  // ============================================

  /// Get the directory for Hive database files
  ///
  /// Returns: [AppData]/hive/
  ///
  /// **Windows:** C:\Users\[User]\AppData\Roaming\com.theoreticalmindstech.voltcore\hive\
  ///
  /// This should be set in Hive.initFlutter():
  /// ```dart
  /// final hiveDir = await FileStorageService.instance.getHiveDirectory();
  /// await Hive.initFlutter(hiveDir.path);
  /// ```
  Future<Directory> getHiveDirectory() async {
    final appData = await getAppDataDirectory();
    final dir = Directory(path.join(appData.path, _dirHive));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      if (kDebugMode) {
        debugPrint('[FileStorage] Created Hive directory: ${dir.path}');
      }
    }

    return dir;
  }

  // ============================================
  // Signature Storage
  // ============================================

  /// Get the base directory for signatures
  ///
  /// Returns: [AppData]/signatures/
  Future<Directory> getSignaturesDirectory() async {
    final appData = await getAppDataDirectory();
    final dir = Directory(path.join(appData.path, _dirSignatures));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get directory for inspection signatures
  ///
  /// Returns: [AppData]/signatures/inspections/
  Future<Directory> getInspectionSignaturesDirectory() async {
    final signatures = await getSignaturesDirectory();
    final dir = Directory(path.join(signatures.path, _dirInspections));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get directory for maintenance signatures
  ///
  /// Returns: [AppData]/signatures/maintenance/
  Future<Directory> getMaintenanceSignaturesDirectory() async {
    final signatures = await getSignaturesDirectory();
    final dir = Directory(path.join(signatures.path, _dirMaintenance));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Save an inspection signature
  ///
  /// [inspectionId]: Unique inspection ID
  /// [signatureBytes]: PNG image bytes
  ///
  /// Returns: Path to saved signature file
  Future<String> saveInspectionSignature({
    required String inspectionId,
    required Uint8List signatureBytes,
  }) async {
    final dir = await getInspectionSignaturesDirectory();
    final file = File(path.join(dir.path, '$inspectionId.png'));

    await file.writeAsBytes(signatureBytes);

    if (kDebugMode) {
      debugPrint('[FileStorage] Saved inspection signature: ${file.path}');
    }

    return file.path;
  }

  /// Save a maintenance signature
  Future<String> saveMaintenanceSignature({
    required String jobId,
    required Uint8List signatureBytes,
    required String signatureType,
  }) async {
    final dir = await getMaintenanceSignaturesDirectory();
    final file = File(path.join(dir.path, '$jobId.png'));

    await file.writeAsBytes(signatureBytes);

    if (kDebugMode) {
      debugPrint('[FileStorage] Saved maintenance signature: ${file.path}');
    }

    return file.path;
  }

  /// Get inspection signature file
  Future<File?> getInspectionSignature(String inspectionId) async {
    final dir = await getInspectionSignaturesDirectory();
    final file = File(path.join(dir.path, '$inspectionId.png'));

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  /// Get maintenance signature file
  Future<File?> getMaintenanceSignature(String jobId, String technician) async {
    final dir = await getMaintenanceSignaturesDirectory();
    final file = File(path.join(dir.path, '$jobId.png'));

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  // ============================================
  // PDF Storage
  // ============================================

  /// Get the base directory for PDFs
  ///
  /// Returns: [AppData]/pdfs/
  Future<Directory> getPdfsDirectory() async {
    final appData = await getAppDataDirectory();
    final dir = Directory(path.join(appData.path, _dirPdfs));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get directory for inspection PDFs
  ///
  /// Returns: [AppData]/pdfs/inspections/
  Future<Directory> getInspectionPdfsDirectory() async {
    final pdfs = await getPdfsDirectory();
    final dir = Directory(path.join(pdfs.path, _dirInspections));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get directory for maintenance PDFs
  ///
  /// Returns: [AppData]/pdfs/maintenance/
  Future<Directory> getMaintenancePdfsDirectory() async {
    final pdfs = await getPdfsDirectory();
    final dir = Directory(path.join(pdfs.path, _dirMaintenance));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Save an inspection PDF
  ///
  /// [inspectionId]: Unique inspection ID
  /// [pdfBytes]: PDF file bytes
  /// [filename]: Optional custom filename (defaults to inspectionId.pdf)
  ///
  /// Returns: Path to saved PDF file
  Future<String> saveInspectionPdf({
    required String inspectionId,
    required Uint8List pdfBytes,
    String? filename,
  }) async {
    final dir = await getInspectionPdfsDirectory();
    final name = filename ?? '$inspectionId.pdf';
    final file = File(path.join(dir.path, name));

    await file.writeAsBytes(pdfBytes);

    if (kDebugMode) {
      debugPrint('[FileStorage] Saved inspection PDF: ${file.path}');
    }

    return file.path;
  }

  /// Save a maintenance PDF
  Future<String> saveMaintenancePdf({
    required String jobId,
    required Uint8List pdfBytes,
    String? filename,
  }) async {
    final dir = await getMaintenancePdfsDirectory();
    final name = filename ?? '$jobId.pdf';
    final file = File(path.join(dir.path, name));

    await file.writeAsBytes(pdfBytes);

    if (kDebugMode) {
      debugPrint('[FileStorage] Saved maintenance PDF: ${file.path}');
    }

    return file.path;
  }

  /// Get inspection PDF file
  Future<File?> getInspectionPdf(String inspectionId, {String? filename}) async {
    final dir = await getInspectionPdfsDirectory();
    final name = filename ?? '$inspectionId.pdf';
    final file = File(path.join(dir.path, name));

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  /// Get maintenance PDF file
  Future<File?> getMaintenancePdf(String jobId, {String? filename}) async {
    final dir = await getMaintenancePdfsDirectory();
    final name = filename ?? '$jobId.pdf';
    final file = File(path.join(dir.path, name));

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  // ============================================
  // Downloads & Temporary Storage
  // ============================================

  /// Get temporary directory
  ///
  /// Returns: [AppData]/temp/
  ///
  /// Use for short-lived files that should be cleaned up
  Future<Directory> getTempDirectory() async {
    final appData = await getAppDataDirectory();
    final dir = Directory(path.join(appData.path, _dirTemp));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get downloads directory (in cache)
  ///
  /// Returns: [App Cache]/downloads/
  Future<Directory> getDownloadsDirectory() async {
    final cache = await getCacheDirectory();
    final dir = Directory(path.join(cache.path, _dirDownloads));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Get external downloads directory (user-accessible)
  ///
  /// Returns platform's downloads folder for user access
  ///
  /// **Windows:** C:\Users\[User]\Downloads
  /// **Mobile:** Downloads directory
  ///
  /// This is where you should save PDFs that users want to share
  Future<Directory?> getExternalDownloadsDirectory() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // On desktop, use system Downloads folder
      final home = Platform.environment['USERPROFILE'] ?? // Windows
          Platform.environment['HOME'];          // Mac/Linux
      if (home != null) {
        final downloads = Directory(path.join(home, 'Downloads'));
        if (await downloads.exists()) {
          return downloads;
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // On mobile, use Downloads directory
      return await getDownloadsDirectory();
    }

    // Fallback
    return await getDownloadsDirectory();
  }

  // ============================================
  // Utility Functions
  // ============================================

  /// Clean up old temporary files
  ///
  /// Deletes files older than [maxAge] from temp directory
  Future<void> cleanTempFiles({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final dir = await getTempDirectory();
      final cutoff = DateTime.now().subtract(maxAge);

      int deletedCount = 0;

      await for (final entity in dir.list()) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              await entity.delete();
              deletedCount++;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FileStorage] Error cleaning file ${entity.path}: $e');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[FileStorage] Cleaned $deletedCount temp files');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FileStorage] Error cleaning temp files: $e');
      }
    }
  }

  /// Clean up cache directory
  Future<void> cleanCache() async {
    try {
      final cache = await getCacheDirectory();

      if (await cache.exists()) {
        await cache.delete(recursive: true);
        await cache.create();

        if (kDebugMode) {
          debugPrint('[FileStorage] Cache cleared');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FileStorage] Error cleaning cache: $e');
      }
    }
  }

  /// Get total size of all stored files (safe version)
  ///
  /// Skips protected directories and handles errors gracefully
  Future<int> getTotalStorageSize() async {
    int total = 0;

    try {
      final appData = await getAppDataDirectory();

      total += await _getDirectorySize(appData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FileStorage] Error calculating storage size: $e');
      }
    }

    return total;
  }

  /// Safely get directory size, skipping protected folders
  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;

    try {
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            size += stat.size;
          } else if (entity is Directory) {
            // Skip protected/system directories
            if (_isProtectedDirectory(entity.path)) {
              continue;
            }
            size += await _getDirectorySize(entity);
          }
        } catch (e) {
          // Skip files/folders we can't access
          if (kDebugMode) {
            debugPrint('[FileStorage] Skipping inaccessible: ${entity.path}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FileStorage] Error scanning directory ${dir.path}: $e');
      }
    }

    return size;
  }

  /// Check if directory is protected/system folder
  bool _isProtectedDirectory(String dirPath) {
    final lowerPath = dirPath.toLowerCase();

    // Windows protected folders
    final protectedFolders = [
      'my music',
      'my pictures',
      'my videos',
      'my documents',
      'saved games',
      'contacts',
      'favorites',
      'links',
      'searches',
    ];

    for (final folder in protectedFolders) {
      if (lowerPath.contains(folder)) {
        return true;
      }
    }

    return false;
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Print debug info about storage
  Future<void> printDebugInfo() async {
    if (!kDebugMode) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('FILE STORAGE DEBUG INFO');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final appData = await getAppDataDirectory();
      debugPrint('App Data: ${appData.path}');

      final cache = await getCacheDirectory();
      debugPrint('Cache: ${cache.path}');

      final totalSize = await getTotalStorageSize();
      debugPrint('Total Size: ${formatBytes(totalSize)}');

      debugPrint('');
      debugPrint('Directories:');
      debugPrint('  Hive: ${(await getHiveDirectory()).path}');
      debugPrint('  Signatures: ${(await getSignaturesDirectory()).path}');
      debugPrint('  PDFs: ${(await getPdfsDirectory()).path}');
      debugPrint('  Temp: ${(await getTempDirectory()).path}');
    } catch (e) {
      debugPrint('Error getting storage info: $e');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}