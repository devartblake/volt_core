import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task_schedule_entity.dart';
import '../../infra/models/schedule_model.dart';

/// Riverpod provider for the remote datasource
final scheduleRemoteDatasourceProvider =
Provider<ScheduleRemoteDatasource>((ref) {
  return ScheduleRemoteDatasource();
});

/// Remote datasource for schedule tasks over Supabase.
///
/// Adjust table name / column names to match your schema.
class ScheduleRemoteDatasource {
  static const String scheduleTable = 'schedule_tasks';

  final SupabaseClient _client;

  ScheduleRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch all schedule tasks (you can later add filters for tenant/user/date).
  Future<List<TaskScheduleEntity>> fetchSchedule() async {
    final response = await _client
        .from(scheduleTable)
        .select()
        .order('scheduled_date', ascending: true);

    final list = (response as List).cast<Map<String, dynamic>>();

    return list
        .map((json) => ScheduleModel.fromJson(json).toEntity())
        .toList();
  }

  /// Upsert a schedule task (create or update).
  Future<TaskScheduleEntity> upsertTask(TaskScheduleEntity entity) async {
    final model = ScheduleModel.fromEntity(entity);
    final payload = model.toJson();

    final response =
    await _client.from(scheduleTable).upsert(payload).select().single();

    return ScheduleModel.fromJson(
      (response as Map<String, dynamic>),
    ).toEntity();
  }

  /// Delete a schedule task by id (optional helper).
  Future<void> deleteTask(String id) async {
    await _client.from(scheduleTable).delete().eq('id', id);
  }
}
