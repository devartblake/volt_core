import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/services/storage/file_storage_service.dart';
import '../../../../core/services/storage/web_file_store.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/form_response_report_artifact.dart';
import '../../domain/entities/template_entities.dart';
import '../repositories/form_response_report_repository.dart';
import 'template_pdf_report_service.dart';

enum TemplateReportCategory { inspection, maintenance, other }

class TemplateReportArtifact {
  const TemplateReportArtifact({
    required this.path,
    required this.category,
    required this.responseId,
    required this.bytes,
    this.link,
  });

  final String path;
  final TemplateReportCategory category;
  final String responseId;
  final Uint8List bytes;
  final FormResponseReportArtifact? link;
}

/// Renders and persists one completed template response using Voltcore's
/// existing PDF storage conventions.
///
/// Native platforms write into the managed `pdfs/` tree consumed by the
/// Documents library. Web writes the same logical path into [WebFileStore], so
/// Edge/Chrome users can reopen and share the report without `dart:io`.
///
/// When [artifacts] is supplied, the stored report is also registered with the
/// immutable server-side response-artifact boundary. The database derives all
/// tenant/customer/site/asset/work-order/inspection/maintenance links from the
/// completed response rather than trusting client-supplied relationship ids.
class TemplateReportStorageService {
  const TemplateReportStorageService({
    this.renderer = const TemplatePdfReportService(),
    this.artifacts,
  });

  final TemplatePdfReportService renderer;
  final FormResponseReportRepository? artifacts;

  Future<TemplateReportArtifact> generateAndSave({
    required FormTemplateDefinition definition,
    required FormResponse response,
    TemplateReportAttachmentResolver? attachmentResolver,
  }) async {
    if (!response.isComplete) {
      throw StateError(
        'Only completed template responses can be persisted as reports.',
      );
    }

    final bytes = await renderer.build(
      definition: definition,
      response: response,
      attachmentResolver: attachmentResolver,
    );
    final category = _categoryFor(response);
    final filename = 'template_${response.id}.pdf';
    final logicalPath = 'pdfs/${_folderFor(category)}/$filename';

    final storedPath = kIsWeb
        ? await _saveWeb(logicalPath, bytes)
        : await _saveNative(
            category: category,
            response: response,
            filename: filename,
            logicalPath: logicalPath,
            bytes: bytes,
          );

    final repository = artifacts;
    final link = repository == null
        ? null
        : await repository.create(
            responseId: response.id,
            storagePath: logicalPath,
            fileName: filename,
            byteSize: bytes.length,
          );

    return TemplateReportArtifact(
      path: storedPath,
      category: category,
      responseId: response.id,
      bytes: bytes,
      link: link,
    );
  }

  Future<String> _saveWeb(String logicalPath, Uint8List bytes) async {
    await WebFileStore.instance.put(logicalPath, bytes);
    await SyncService.instance.enqueueBytesUpload(
      storePath: logicalPath,
      remotePath: logicalPath,
      contentType: 'application/pdf',
    );
    return logicalPath;
  }

  Future<String> _saveNative({
    required TemplateReportCategory category,
    required FormResponse response,
    required String filename,
    required String logicalPath,
    required Uint8List bytes,
  }) async {
    final storage = FileStorageService.instance;
    late final String storedPath;

    switch (category) {
      case TemplateReportCategory.inspection:
        storedPath = await storage.saveInspectionPdf(
          inspectionId:
              response.inspectionId ?? response.subjectId ?? response.id,
          pdfBytes: bytes,
          filename: filename,
        );
      case TemplateReportCategory.maintenance:
        storedPath = await storage.saveMaintenancePdf(
          jobId:
              response.maintenanceRecordId ?? response.subjectId ?? response.id,
          pdfBytes: bytes,
          filename: filename,
        );
      case TemplateReportCategory.other:
        final root = await storage.getPdfsDirectory();
        final directory = Directory(
          '${root.path}${Platform.pathSeparator}template-responses',
        );
        if (!await directory.exists()) await directory.create(recursive: true);
        final file = File(
          '${directory.path}${Platform.pathSeparator}$filename',
        );
        await file.writeAsBytes(bytes);
        storedPath = file.path;
    }

    await SyncService.instance.enqueueFileUpload(
      localPath: storedPath,
      remotePath: logicalPath,
      contentType: 'application/pdf',
    );
    return storedPath;
  }

  static TemplateReportCategory _categoryFor(FormResponse response) {
    if ((response.inspectionId?.isNotEmpty ?? false) ||
        response.subjectType.contains('inspection')) {
      return TemplateReportCategory.inspection;
    }
    if ((response.maintenanceRecordId?.isNotEmpty ?? false) ||
        response.subjectType.contains('maintenance')) {
      return TemplateReportCategory.maintenance;
    }
    return TemplateReportCategory.other;
  }

  static String _folderFor(TemplateReportCategory category) => switch (category) {
        TemplateReportCategory.inspection => 'inspections',
        TemplateReportCategory.maintenance => 'maintenance',
        TemplateReportCategory.other => 'template-responses',
      };
}
