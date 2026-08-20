import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/infra/mappers/schedule_supabase_mapper.dart';

TaskScheduleEntity _task({
  String id = 't1',
  String tenantId = '',
  String status = 'scheduled',
}) {
  final at = DateTime.utc(2026, 7, 21, 9);
  return TaskScheduleEntity(
    id: id,
    tenantId: tenantId,
    title: 'Annual load test',
    description: 'Bring the load bank',
    scheduledAt: at,
    scheduledDate: DateTime.utc(2026, 7, 21),
    status: status,
    sourceType: 'inspection',
    sourceId: 'insp-9',
    inspectionId: 'insp-9',
    siteCode: 'AS-114',
    siteGrade: 'Green',
    address: '114 Broadway',
    assignedToUserId: 'user-7',
    notes: 'Gate code 1234',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

void main() {
  group('scheduleTaskToSupabaseJson', () {
    test('maps every column the schedule_tasks table defines', () {
      final json = scheduleTaskToSupabaseJson(_task());

      expect(json['id'], 't1');
      expect(json['title'], 'Annual load test');
      expect(json['description'], 'Bring the load bank');
      expect(json['status'], 'scheduled');
      expect(json['source_type'], 'inspection');
      expect(json['source_id'], 'insp-9');
      expect(json['inspection_id'], 'insp-9');
      expect(json['site_code'], 'AS-114');
      expect(json['site_grade'], 'Green');
      expect(json['address'], '114 Broadway');
      expect(json['assigned_to_user_id'], 'user-7');
      expect(json['notes'], 'Gate code 1234');
    });

    test('uses schedule_at, matching the table and the read-back parser', () {
      final json = scheduleTaskToSupabaseJson(_task());

      // Migration 0003 names this column `schedule_at`, and
      // ScheduleTaskModel.fromJson reads the same key. A mismatch here would
      // silently drop the appointment time.
      expect(json.containsKey('schedule_at'), isTrue);
      expect(json.containsKey('scheduled_at'), isFalse);
      expect(json['schedule_at'], DateTime.utc(2026, 7, 21, 9).toIso8601String());
      expect(
        json['scheduled_date'],
        DateTime.utc(2026, 7, 21).toIso8601String(),
      );
    });

    test('prefers the entity tenant when it carries one', () {
      final json = scheduleTaskToSupabaseJson(_task(tenantId: 'tenant-abc'));
      expect(json['tenant_id'], 'tenant-abc');
    });

    test('always emits a tenant_id key (column is NOT NULL)', () {
      final json = scheduleTaskToSupabaseJson(_task());
      expect(json.containsKey('tenant_id'), isTrue);
      expect(json['tenant_id'], isA<String>());
    });

    test('timestamps round-trip as ISO-8601 strings', () {
      final json = scheduleTaskToSupabaseJson(_task());
      expect(DateTime.parse(json['created_at'] as String),
          DateTime.utc(2026, 7, 1));
      expect(DateTime.parse(json['updated_at'] as String),
          DateTime.utc(2026, 7, 2));
    });

    test('table constant matches the migration', () {
      expect(kScheduleTasksTable, 'schedule_tasks');
    });
  });
}
