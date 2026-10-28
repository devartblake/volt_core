import '../../../modules/fleet/domain/entities/vehicle_entity.dart';
import '../../../modules/fleet/domain/entities/vehicle_inspection.dart';
import '../../../modules/fleet/domain/entities/vehicle_maintenance_check.dart';

/// One tool line on the vehicle report.
class VehicleReportAsset {
  const VehicleReportAsset({
    required this.label,
    required this.status,
    this.serial = '',
    this.notes = '',
  });

  final String label;
  final String status;
  final String serial;
  final String notes;
}

/// Everything the vehicle PDF prints, gathered by the caller so the PDF
/// service stays free of repositories and providers.
class VehicleReportData {
  const VehicleReportData({
    required this.vehicle,
    this.driverName,
    this.inspections = const [],
    this.checks = const [],
    this.assets = const [],
  });

  final VehicleEntity vehicle;
  final String? driverName;

  /// Newest first.
  final List<VehicleInspection> inspections;
  final List<VehicleMaintenanceCheck> checks;
  final List<VehicleReportAsset> assets;
}
