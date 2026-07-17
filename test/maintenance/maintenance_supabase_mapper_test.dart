import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/maintenance/infra/mappers/maintenance_supabase_mapper.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

void main() {
  group('maintenanceRecordToSupabaseJson', () {
    test('maps core fields to snake_case', () {
      final rec = MaintenanceRecord(
        id: 'm1',
        siteCode: 'S1',
        address: '123 Main St',
        technicianName: 'Alex',
        completed: true,
      );

      final map = maintenanceRecordToSupabaseJson(rec);

      expect(map['id'], 'm1');
      expect(map['site_code'], 'S1');
      expect(map['address'], '123 Main St');
      expect(map['technician_name'], 'Alex');
      expect(map['completed'], true);
      // Nullable date serializes to null rather than throwing.
      expect(map['date_of_service'], isNull);
      // Timestamps are always present.
      expect(map['created_at'], isNotNull);
      expect(map['updated_at'], isNotNull);
    });

    test('table constant is stable', () {
      expect(kMaintenanceRecordsTable, 'maintenance_records');
    });
  });
}
