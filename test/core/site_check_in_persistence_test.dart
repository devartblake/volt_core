import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/location/site_check_in.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/infra/datasources/inspection_remote_datasource.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/maintenance/infra/mappers/maintenance_supabase_mapper.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

/// A check-in is worth nothing if it does not survive the trip to storage and
/// back. Inspections and maintenance take completely different routes — flat
/// Hive columns plus `payload` jsonb versus flat columns plus `data` jsonb —
/// so each is checked end to end.
void main() {
  final brooklyn = SiteCheckIn(
    latitude: 40.7061,
    longitude: -73.9369,
    accuracyMeters: 8,
    capturedAt: DateTime.utc(2026, 9, 16, 14, 30),
  );

  group('inspection', () {
    test('survives the Hive round trip', () {
      final original =
          InspectionEntity.newDraft().copyWith(siteCheckIn: brooklyn);

      final restored = inspectionFromEntity(original).toEntity();

      expect(restored.siteCheckIn, isNotNull);
      expect(restored.siteCheckIn!.latitude, 40.7061);
      expect(restored.siteCheckIn!.longitude, -73.9369);
      expect(restored.siteCheckIn!.accuracyMeters, 8);
      expect(restored.siteCheckIn!.capturedAt, brooklyn.capturedAt);
    });

    test('rides in the payload, so no migration is needed', () {
      final row = InspectionRemoteDatasource.toSupabaseJson(
        InspectionEntity.newDraft().copyWith(siteCheckIn: brooklyn),
      );
      final payload = row['payload'] as Map<String, dynamic>;

      expect(payload['site_check_in'], isA<Map>());
      expect((payload['site_check_in'] as Map)['latitude'], 40.7061);
      // Not a new top-level column: `inspections` is untouched by this feature.
      expect(row.containsKey('site_check_in'), isFalse);
    });

    test('an inspection without one stays null rather than becoming (0, 0)',
        () {
      final restored =
          inspectionFromEntity(InspectionEntity.newDraft()).toEntity();

      expect(restored.siteCheckIn, isNull);
    });

    test('clearSiteCheckIn actually clears it', () {
      // A plain copyWith(siteCheckIn: null) cannot tell "leave it alone" from
      // "remove it" — the same trap as clearVin and clearAssignee.
      final withIt = InspectionEntity.newDraft().copyWith(siteCheckIn: brooklyn);

      expect(withIt.copyWith().siteCheckIn, isNotNull);
      expect(withIt.copyWith(clearSiteCheckIn: true).siteCheckIn, isNull);
    });

    test('a stored Null Island pair reads back as no check-in', () {
      // Belt and braces: the service refuses to capture (0, 0), and the model
      // refuses to hand one back even if a row somehow holds it.
      final model = inspectionFromEntity(InspectionEntity.newDraft())
        ..checkInLatitude = 0
        ..checkInLongitude = 0;

      expect(model.toEntity().siteCheckIn, isNull);
    });
  });

  group('maintenance', () {
    test('round-trips through the data jsonb', () {
      final record = MaintenanceRecord(id: 'm1');
      applyMaintenanceCheckIn(record, brooklyn);

      final data = maintenanceRecordData(record);
      expect(data['site_check_in'], isA<Map>());

      final restored = SiteCheckIn.fromJson(data['site_check_in'])!;
      expect(restored.latitude, 40.7061);
      expect(restored.accuracyMeters, 8);
      expect(restored.capturedAt, brooklyn.capturedAt);
    });

    test('applying null clears every column', () {
      final record = MaintenanceRecord(id: 'm1');
      applyMaintenanceCheckIn(record, brooklyn);
      applyMaintenanceCheckIn(record, null);

      expect(record.checkInLatitude, isNull);
      expect(record.checkInLongitude, isNull);
      expect(record.checkInAccuracyM, isNull);
      expect(record.checkInAt, isNull);
      expect(maintenanceCheckIn(record), isNull);
      expect(maintenanceRecordData(record)['site_check_in'], isNull);
    });

    test('a record without one stays null', () {
      expect(maintenanceCheckIn(MaintenanceRecord(id: 'm1')), isNull);
    });

    test('a stored Null Island pair reads back as no check-in', () {
      final record = MaintenanceRecord(id: 'm1')
        ..checkInLatitude = 0
        ..checkInLongitude = 0;

      expect(maintenanceCheckIn(record), isNull);
    });
  });

  test('both modules store the same shape', () {
    // The whole reason SiteCheckIn is shared: a reader joining the two sources
    // should not have to learn two formats.
    final inspectionPayload = InspectionRemoteDatasource.toSupabaseJson(
      InspectionEntity.newDraft().copyWith(siteCheckIn: brooklyn),
    )['payload'] as Map<String, dynamic>;

    final record = MaintenanceRecord(id: 'm1');
    applyMaintenanceCheckIn(record, brooklyn);

    expect(
      inspectionPayload['site_check_in'],
      maintenanceRecordData(record)['site_check_in'],
    );
  });
}
