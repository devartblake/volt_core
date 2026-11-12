import 'dart:typed_data';

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

/// One photo already read into memory for the vehicle PDF.
class VehicleReportPhoto {
  const VehicleReportPhoto({required this.bytes, this.caption = ''});

  final Uint8List bytes;
  final String caption;
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
    this.driverSignature,
    this.dispatcherSignature,
    this.vehiclePhotos = const [],
    this.inspectionPhotos = const [],
  });

  final VehicleEntity vehicle;
  final String? driverName;

  /// Newest first.
  final List<VehicleInspection> inspections;
  final List<VehicleMaintenanceCheck> checks;
  final List<VehicleReportAsset> assets;

  /// Signatures on the latest inspection (PNG bytes), when captured.
  final Uint8List? driverSignature;
  final Uint8List? dispatcherSignature;

  /// Photos taken on the vehicle itself, and those from the latest inspection.
  final List<VehicleReportPhoto> vehiclePhotos;
  final List<VehicleReportPhoto> inspectionPhotos;

  /// Copy with media filled in. Media already present is kept when the
  /// argument is null.
  VehicleReportData withMedia({
    Uint8List? driverSignature,
    Uint8List? dispatcherSignature,
    List<VehicleReportPhoto>? vehiclePhotos,
    List<VehicleReportPhoto>? inspectionPhotos,
  }) =>
      VehicleReportData(
        vehicle: vehicle,
        driverName: driverName,
        inspections: inspections,
        checks: checks,
        assets: assets,
        driverSignature: driverSignature ?? this.driverSignature,
        dispatcherSignature: dispatcherSignature ?? this.dispatcherSignature,
        vehiclePhotos: vehiclePhotos ?? this.vehiclePhotos,
        inspectionPhotos: inspectionPhotos ?? this.inspectionPhotos,
      );
}
