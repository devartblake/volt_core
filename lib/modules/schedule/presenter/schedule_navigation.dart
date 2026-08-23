import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../domain/entities/task_schedule_entity.dart';

/// Opens a scheduled task's own detail screen.
///
/// A schedule row is not itself a maintenance record (even when it originated
/// from maintenance). The task detail screen exposes its source as a separate
/// optional action, avoiding an invalid maintenance-record lookup.
void openScheduledTask(BuildContext context, TaskScheduleEntity task) {
  context.pushNamed(
    RouteNames.scheduleTaskDetail,
    pathParameters: {'id': task.id},
  );
}
