class TenantRetentionPolicy {
  const TenantRetentionPolicy({
    required this.tenantId,
    this.archivedMaintenanceDays,
    this.generatedReportDays,
  });

  final String tenantId;
  final int? archivedMaintenanceDays;
  final int? generatedReportDays;

  bool get retainsArchivedMaintenanceIndefinitely =>
      archivedMaintenanceDays == null;
  bool get retainsGeneratedReportsIndefinitely => generatedReportDays == null;
}
