import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/task_schedule_entity.dart';

/// Supabase table holding scheduled tasks (created by migration 0003).
const String kScheduleTasksTable = 'schedule_tasks';

/// Serialize a scheduled task to a `public.schedule_tasks` row.
///
/// Column names match migration `0003_missing_tables.sql` exactly — note the
/// timestamp column is `schedule_at`, not `scheduled_at`, matching the shape
/// `ScheduleTaskModel.fromJson` already reads back.
///
/// The tenant is stamped from [SyncContext] rather than the entity: tasks are
/// created locally with an empty `tenantId`, and the server rejects rows whose
/// tenant doesn't match the caller's membership.
Map<String, dynamic> scheduleTaskToSupabaseJson(TaskScheduleEntity e) {
  final tenantId = scheduleTaskTenantId(e);

  return {
    'id': e.id,
    'tenant_id': tenantId,
    'title': e.title,
    'description': e.description,
    'scheduled_date': e.scheduledDate.toIso8601String(),
    'schedule_at': e.scheduledAt.toIso8601String(),
    'status': e.status,
    'source_type': e.sourceType,
    'source_id': e.sourceId,
    'inspection_id': e.inspectionId,
    'site_code': e.siteCode,
    'site_grade': e.siteGrade,
    'address': e.address,
    'assigned_to_user_id': e.assignedToUserId ?? SyncContext.userId,
    'notes': e.notes,
    'created_at': e.createdAt.toIso8601String(),
    'updated_at': e.updatedAt.toIso8601String(),
  };
}

/// Resolves the tenant that will be written for a task.
///
/// The entity wins when it is already tenant-scoped; otherwise tasks inherit
/// the authenticated sync context. A blank result is intentionally not valid
/// for cloud persistence after Phase 1's tenant-RLS migration.
String scheduleTaskTenantId(TaskScheduleEntity e) =>
    e.tenantId.isNotEmpty ? e.tenantId : (SyncContext.tenantId ?? '');

/// Whether a task can safely be written to the tenant-scoped schedule table.
bool hasValidScheduleTaskTenant(TaskScheduleEntity e) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(scheduleTaskTenantId(e));
