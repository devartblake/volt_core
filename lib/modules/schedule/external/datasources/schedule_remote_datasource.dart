import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task_schedule_entity.dart';
import '../../infra/datasources/schedule_remote_datasource.dart';
import '../../infra/models/schedule_model.dart';

/// Riverpod provider for the remote datasource
final scheduleRemoteDatasourceProvider =
    Provider<ScheduleRemoteDatasource>((ref) {
  return ScheduleRemoteDatasourceImpl();
});

/// Concrete Supabase implementation of the schedule remote datasource.
///
/// Adjust table name / column names to match your schema.
class ScheduleRemoteDatasourceImpl implements ScheduleRemoteDatasource {
  static const String scheduleTable = 'schedule_tasks';

  final SupabaseClient _client;

  ScheduleRemoteDatasourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<TaskScheduleEntity>> list({DateTime? from, DateTime? to}) async {
    var query = _client.from(scheduleTable).select();

    if (from != null) {
      query = query.gte('scheduled_date', from.toIso8601String());
    }

    if (to != null) {
      query = query.lte('scheduled_date', to.toIso8601String());
    }

    final response = await query.order('scheduled_date', ascending: true);

    final list = (response as List).cast<Map<String, dynamic>>();

    return list
        .map((json) => ScheduleTaskModel.fromJson(json).toEntity())
        .toList();
  }

  @override
  Future<TaskScheduleEntity?> getById(String id) async {
    final response =
        await _client.from(scheduleTable).select().eq('id', id).maybeSingle();

    if (response == null) return null;

    return ScheduleTaskModel.fromJson(
      (response as Map<String, dynamic>),
    ).toEntity();
  }

  @override
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity entity) async {
    final model = ScheduleTaskModel.fromEntity(entity);
    final payload = model.toJson();

    final response =
        await _client.from(scheduleTable).upsert(payload).select().single();

    return ScheduleTaskModel.fromJson(
      (response as Map<String, dynamic>),
    ).toEntity();
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(scheduleTable).delete().eq('id', id);
  }
}
