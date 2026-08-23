import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/maintenance/infra/mappers/maintenance_supabase_mapper.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

void main() {
  group('maintenanceRecordData (detail jsonb)', () {
    test('serializes detail fields in snake_case', () {
      final rec = MaintenanceRecord(
        id: 'm1',
        siteCode: 'S1',
        address: '123 Main St',
        technicianName: 'Alex',
        completed: true,
        requiresFollowUp: true,
      );

      final data = maintenanceRecordData(rec);

      expect(data['site_code'], 'S1');
      expect(data['address'], '123 Main St');
      expect(data['technician_name'], 'Alex');
      expect(data['completed'], true);
      expect(data['requires_follow_up'], true);
      // A representative deep field is present.
      expect(data.containsKey('coolant_hoses_info'), true);
      // Nullable date serializes to null rather than throwing.
      expect(data['date_of_service'], isNull);
    });

    test('table constants are stable', () {
      expect(kMaintenanceJobsTable, 'maintenance_jobs');
      expect(kMaintenanceRecordsTable, 'maintenance_records');
    });

    test('restores a complete source record after a local-cache reset', () {
      final record = maintenanceRecordFromSupabaseRows(
        job: {
          'id': 'm1',
          'created_at': '2026-08-20T12:00:00.000Z',
          'updated_at': '2026-08-22T15:30:00.000Z',
        },
        details: {
          'data': {
            'inspection_id': 'inspection-1',
            'site_code': 'NY-QN-844',
            'address': '952 Flushing Ave, Brooklyn NY 11206',
            'technician_name': 'Steve Cassar',
            'generator_make': 'Cummins',
            'engine_hours': '300',
            'enclosure_intact': true,
            'completed': true,
            'requires_follow_up': false,
          },
        },
      );

      expect(record.id, 'm1');
      expect(record.inspectionId, 'inspection-1');
      expect(record.siteCode, 'NY-QN-844');
      expect(record.generatorMake, 'Cummins');
      expect(record.enclosureIntact, isTrue);
      expect(record.completed, isTrue);
      expect(record.updatedAt, DateTime.utc(2026, 8, 22, 15, 30));
    });
  });
}
