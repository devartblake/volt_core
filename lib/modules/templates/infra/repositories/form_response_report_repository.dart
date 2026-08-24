import '../../domain/entities/form_response_report_artifact.dart';

abstract class FormResponseReportRepository {
  Future<FormResponseReportArtifact> create({
    required String responseId,
    required String storagePath,
    required String fileName,
    required int byteSize,
    String mediaType = 'application/pdf',
    String? checksumSha256,
  });

  Future<List<FormResponseReportArtifact>> listLinked({
    String? responseId,
    String? customerId,
    String? siteId,
    String? assetId,
    String? workOrderId,
    String? inspectionId,
    String? maintenanceRecordId,
  });
}
