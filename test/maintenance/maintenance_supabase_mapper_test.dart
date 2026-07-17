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
  });
}
