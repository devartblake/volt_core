class FormResponseReportArtifact {
  const FormResponseReportArtifact({
    required this.id,
    required this.tenantId,
    required this.responseId,
    required this.templateRevisionId,
    required this.storagePath,
    required this.fileName,
    required this.mediaType,
    required this.byteSize,
    required this.createdAt,
    this.customerId,
    this.siteId,
    this.assetId,
    this.workOrderId,
    this.inspectionId,
    this.maintenanceRecordId,
    this.checksumSha256,
    this.createdByUserId,
  });

  final String id;
  final String tenantId;
  final String responseId;
  final String templateRevisionId;
  final String? customerId;
  final String? siteId;
  final String? assetId;
  final String? workOrderId;
  final String? inspectionId;
  final String? maintenanceRecordId;
  final String storagePath;
  final String fileName;
  final String mediaType;
  final int byteSize;
  final String? checksumSha256;
  final String? createdByUserId;
  final DateTime createdAt;
}
