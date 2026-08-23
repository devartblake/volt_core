import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/domain/entities/technician_entity.dart';
import '../../admin/infra/repositories/admin_repository_impl.dart';
import '../../auth/domain/user_role.dart';
import '../domain/entities/work_order_entity.dart';
import '../domain/entities/work_order_event.dart';
import '../infra/datasources/work_order_event_remote_datasource.dart';
import '../infra/repositories/work_order_repository_impl.dart';

final workOrderListProvider = FutureProvider<List<WorkOrderEntity>>((ref) {
  return ref.watch(workOrderRepositoryProvider).list();
});

final workOrderProvider = FutureProvider.family<WorkOrderEntity?, String>(
  (ref, id) => ref.watch(workOrderRepositoryProvider).getById(id),
);

/// Server-created history for a work order. A temporarily unavailable network
/// leaves the form usable; the page renders a clear retry affordance instead.
final workOrderEventsProvider =
    FutureProvider.family<List<WorkOrderEvent>, String>((ref, workOrderId) {
      return ref
          .watch(workOrderEventRemoteDatasourceProvider)
          .listForWorkOrder(workOrderId);
    });

/// Active field technicians that can be assigned to a work order.
///
/// Assignment remains optional so dispatch can create an unassigned job while
/// a technician roster is unavailable (for example, during offline work).
final workOrderAssigneesProvider =
    FutureProvider<List<TechnicianEntity>>((ref) async {
  final users = await ref.watch(adminRepositoryProvider).listTechnicians();
  return users.where((user) => user.isActive && user.role.isTech).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});
