import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/work_order_entity.dart';
import '../infra/repositories/work_order_repository_impl.dart';

final workOrderListProvider = FutureProvider<List<WorkOrderEntity>>((ref) {
  return ref.watch(workOrderRepositoryProvider).list();
});

final workOrderProvider = FutureProvider.family<WorkOrderEntity?, String>(
  (ref, id) => ref.watch(workOrderRepositoryProvider).getById(id),
);
