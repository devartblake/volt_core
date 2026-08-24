import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'file_storage_service.dart';
import 'web_file_store.dart';

/// Logical grouping for a generated document.
enum PdfCategory { inspection, maintenance, other }

extension PdfCategoryLabel on PdfCategory {
  String get label {
    switch (this) {
      case PdfCategory.inspection:
        return 'Inspection';
      case PdfCategory.maintenance:
        return 'Maintenance';
      case PdfCategory.other:
        return 'Other';
    }
  }
}

/// Metadata for one generated PDF on disk or in the web byte store.
@immutable
class PdfDocumentInfo {
  const PdfDocumentInfo({
    required this.path,
    required this.name,
    required this.category,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String name;
  final PdfCategory category;
  final int sizeBytes;
  final DateTime modified;

  String get sizeLabel => FileStorageService.formatBytes(sizeBytes);
}

/// Reads and manages generated PDF reports produced by the app.
///
/// Native platforms enumerate the managed `<appData>/pdfs/` tree. Web uses
/// [WebFileStore] logical `pdfs/` paths backed by IndexedDB, which lets the same
/// Documents screen expose reports generated in Edge/Chrome.
class PdfLibraryService {
  PdfLibraryService._();

  static final PdfLibraryService instance = PdfLibraryService._();

  /// All generated PDFs, newest first.
  Future<List<PdfDocumentInfo>> listDocuments() async {
    if (kIsWeb) {
      await WebFileStore.instance.init();
      return WebFileStore.instance
          .listSync(prefix: 'pdfs/')
          .where((item) => item.path.toLowerCase().endsWith('.pdf'))
          .map(
            (item) => PdfDocumentInfo(
              path: item.path,
              name: item.path.split('/').last,
              category: _categoryFor(item.path),
              sizeBytes: item.sizeBytes,
              modified: item.modified.toLocal(),
            ),
          )
          .toList(growable: false);
    }

    final root = await FileStorageService.instance.getPdfsDirectory();
    if (!await root.exists()) return const [];

    final docs = <PdfDocumentInfo>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (path.extension(entity.path).toLowerCase() != '.pdf') continue;

      try {
        final stat = await entity.stat();
        docs.add(
          PdfDocumentInfo(
            path: entity.path,
            name: path.basename(entity.path),
            category: _categoryFor(entity.path),
            sizeBytes: stat.size,
            modified: stat.modified,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PdfLibrary] Skipping ${entity.path}: $e');
        }
      }
    }

    docs.sort((a, b) => b.modified.compareTo(a.modified));
    return docs;
  }

  PdfCategory _categoryFor(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.contains('maintenance')) return PdfCategory.maintenance;
    if (lower.contains('inspection')) return PdfCategory.inspection;
    return PdfCategory.other;
  }

  /// Permanently delete a generated PDF from local storage.
  ///
  /// Note: this removes the local copy only. A cloud backup (if already
  /// uploaded) is left intact.
  Future<void> deleteDocument(String filePath) async {
    if (kIsWeb) {
      await WebFileStore.instance.remove(filePath);
      return;
    }

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      if (kDebugMode) debugPrint('[PdfLibrary] Deleted $filePath');
    }
  }
}
