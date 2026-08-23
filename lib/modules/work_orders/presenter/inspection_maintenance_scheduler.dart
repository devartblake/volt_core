import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../providers/equipment_providers.dart';
import '../../customers/customer_site_repository.dart';
import '../../inspections/domain/entities/inspection_entity.dart';
import '../application/inspection_maintenance_handoff.dart';
import '../infra/repositories/work_order_repository_impl.dart';
import 'work_order_providers.dart';

/// Creates a scheduled maintenance work order from inspection evidence and
/// opens it for dispatch review. Missing directory data never blocks the
/// handoff; the job is still created with the inspection source notes.
Future<void> scheduleMaintenanceFromInspection(
  BuildContext context,
  WidgetRef ref,
  InspectionEntity inspection,
) async {
  final now = DateTime.now();
  final scheduledFor = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
    helpText: 'Schedule maintenance',
  );
  if (scheduledFor == null || !context.mounted) return;

  CustomerSiteDirectory directory = const CustomerSiteDirectory();
  List<Equipment> equipment = const [];
  try {
    directory = await ref.read(customerSiteDirectoryProvider.future);
  } catch (_) {
    // The source details remain in the job even while the directory is offline.
  }
  try {
    equipment = await ref.read(equipmentListProvider.future);
  } catch (_) {
    // An unlinked asset is preferable to losing the maintenance request.
  }

  try {
    final draft = InspectionMaintenanceHandoff.draftFor(
      inspection,
      directory: directory,
      equipment: equipment,
      scheduledFor: scheduledFor,
    );
    final order = await ref.read(workOrderRepositoryProvider).create(
          title: draft.title,
          priority: draft.priority,
          customerId: draft.customerId,
          siteId: draft.siteId,
          assetId: draft.assetId,
          scheduledFor: draft.scheduledFor,
          description: draft.description,
        );
    ref.invalidate(workOrderListProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenance job scheduled.')),
    );
    context.goNamed(
      RouteNames.workOrderEdit,
      pathParameters: {'id': order.id},
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule maintenance: $error')),
      );
    }
  }
}
