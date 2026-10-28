import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/pdf/pdf_service.dart';
import '../../../core/services/pdf/vehicle_report_data.dart';
import '../../admin/domain/entities/tenant_member_entity.dart';
import '../../maintenance/presenter/utils/maintenance_pdf_actions.dart';
import '../domain/entities/vehicle_asset.dart';
import '../domain/entities/vehicle_entity.dart';
import '../domain/entities/vehicle_inspection.dart';
import '../domain/entities/vehicle_maintenance_check.dart';
import '../infra/repositories/vehicle_asset_repository.dart';
import '../infra/repositories/vehicle_check_repository.dart';
import '../infra/repositories/vehicle_inspection_repository.dart';
import 'fleet_providers.dart';

/// Gathers everything about [vehicle], builds the PDF, stores it in the
/// document library and offers to open it. Reports the real outcome, with a
/// Retry on failure.
Future<void> generateVehiclePdfWithFeedback(
  BuildContext context,
  WidgetRef ref,
  VehicleEntity vehicle,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  messenger.showSnackBar(
    const SnackBar(
      content: Text('Generating vehicle PDF…'),
      behavior: SnackBarBehavior.floating,
    ),
  );

  try {
    // Each source is best-effort: a tool list that fails to load should not
    // stop the rest of the report from being produced.
    Future<T> orDefault<T>(Future<T> Function() load, T fallback) async {
      try {
        return await load();
      } catch (_) {
        return fallback;
      }
    }

    final inspections = await orDefault(
      () => ref
          .read(vehicleInspectionRepositoryProvider)
          .listForVehicle(vehicle.id),
      const <VehicleInspection>[],
    );
    final checks = await orDefault(
      () => ref.read(vehicleCheckRepositoryProvider).listForVehicle(vehicle.id),
      const <VehicleMaintenanceCheck>[],
    );
    final tools = await orDefault(
      () => ref.read(vehicleAssetRepositoryProvider).listForVehicle(vehicle.id),
      const <ResolvedVehicleAsset>[],
    );
    final members = await orDefault(
      () => ref.read(fleetAssignableMembersProvider.future),
      const <TenantMemberEntity>[],
    );

    String? driver;
    if (vehicle.isAssigned) {
      driver = 'Former member';
      for (final m in members) {
        if (m.userId == vehicle.assignedToUserId) driver = m.displayName;
      }
    }

    final result = await PdfService.instance.generateVehiclePdf(
      VehicleReportData(
        vehicle: vehicle,
        driverName: driver,
        inspections: inspections,
        checks: checks,
        assets: [
          for (final t in tools)
            VehicleReportAsset(
              label: t.displayLabel,
              serial: t.asset.serialNumber ?? '',
              status: t.asset.isMissing
                  ? 'Missing'
                  : t.asset.readiness.label,
              notes: t.asset.notes,
            ),
        ],
      ),
    );
    showMaintenancePdfSavedSnack(
      messenger,
      navigator,
      result,
      message: 'Vehicle PDF saved',
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not generate vehicle PDF: $e'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
