import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/entities/nameplate_entity.dart';

/// Riverpod provider for the remote datasource
final inspectionRemoteDatasourceProvider =
Provider<InspectionRemoteDatasource>((ref) {
  return InspectionRemoteDatasource();
});

/// Remote datasource for inspections over Supabase.
///
/// Adjust table names/columns to match your schema.
class InspectionRemoteDatasource {
  static const String inspectionsTable = 'inspections';
  static const String nameplatesTable = 'nameplate_data';

  final SupabaseClient _client;

  InspectionRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // NEW: Modern saveInspection (create + update)
  // ---------------------------------------------------------------------------
  Future<void> saveInspection(InspectionEntity entity) async {
    final payload = _inspectionToJson(entity);

    // Remove nulls since Supabase rejects nulls on non-nullable columns
    payload.removeWhere((key, value) => value == null);

    await _client.from(inspectionsTable).upsert(payload);

    // We intentionally return void.
    // The repository already manages returning updated entities.
  }

  Future<List<InspectionEntity>> fetchInspections() async {
    final response = await _client
        .from(inspectionsTable)
        .select()
        .order('created_at', ascending: false);

    final list = (response as List).cast<Map<String, dynamic>>();

    return list.map(_mapInspectionFromJson).toList();
  }

  Future<InspectionEntity> upsertInspection(InspectionEntity entity) async {
    final payload = _inspectionToJson(entity);
    final response = await _client
        .from(inspectionsTable)
        .upsert(payload)
        .select()
        .single();

    return _mapInspectionFromJson(
      (response as Map<String, dynamic>),
    );
  }

  Future<List<NameplateEntity>> fetchNameplatesForInspection(
      String inspectionId) async {
    final response = await _client
        .from(nameplatesTable)
        .select()
        .eq('inspection_id', inspectionId);

    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(_mapNameplateFromJson).toList();
  }

  // ---- Mapping helpers ----

  InspectionEntity _mapInspectionFromJson(Map<String, dynamic> json) {
    // Rows store identity columns at the top level and detail fields under the
    // `payload` jsonb column. Merge payload over the top level so we can read by
    // key regardless of shape (also tolerates legacy flat rows).
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final m = <String, dynamic>{...json, ...payload};

    return InspectionEntity(
      id: m['id'].toString(),
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(
              m['client_updated_at'] ?? m['updated_at'] ?? '') ??
          DateTime.now(),
      siteCode: m['site_code'] ?? '',
      siteGrade: m['site_grade'] ?? '',
      address: m['address'] ?? '',
      serviceDate: DateTime.tryParse(m['service_date'] ?? '') ?? DateTime.now(),
      technicianName: m['technician_name'] ?? '',
      generatorMake: m['generator_make'] ?? '',
      generatorModel: m['generator_model'] ?? '',
      generatorSerial: m['generator_serial'] ?? '',
      generatorKw: m['generator_kw'] ?? '',
      engineHours: m['engine_hours'] ?? '',
      fuelType: m['fuel_type'] ?? '',
      voltageRating: m['voltage_rating'] ?? '',
      locIndoors: m['loc_indoors'] ?? false,
      locOutdoors: m['loc_outdoors'] ?? false,
      locRoof: m['loc_roof'] ?? false,
      locBasement: m['loc_basement'] ?? false,
      locOther: m['loc_other'] ?? '',
      dedicatedRoom2hr: m['dedicated_room_2hr'] ?? false,
      separateFromMainService: m['separate_from_main_service'] ?? false,
      areaClear: m['area_clear'] ?? false,
      labelsAndEStopVisible: m['labels_estop_visible'] ?? false,
      extinguisherPresent: m['extinguisher_present'] ?? false,
      fuelStoredType: m['fuel_stored_type'] ?? '',
      fuelQtyGallons: m['fuel_qty_gallons'] ?? '',
      fdnyPermit: m['fdny_permit'] ?? 'Unknown',
      c92OnSite: m['c92_on_site'] ?? 'Unknown',
      gasCutoffValve: m['gas_cutoff_valve'] ?? 'N/A',
      depSizeKw: m['dep_size_kw'] ?? '',
      depRegisteredCats: m['dep_registered_cats'] ?? 'Unknown',
      depCertificateOperate: m['dep_certificate_operate'] ?? 'Unknown',
      tier4Compliant: m['tier4_compliant'] ?? 'Unknown',
      smokeOrStackTest: m['smoke_or_stack_test'] ?? 'Unknown',
      recordsKept5Years: m['records_kept_5_years'] ?? false,
      emergencyOnly: m['emergency_only'] ?? true,
      estimatedAnnualRuntimeHours: m['estimated_annual_runtime_hours'] ?? '',
      fuelFor6hrs: m['fuel_for_6hrs'] ?? 'N/A',
      notes: m['notes'] ?? '',
      gensetRunsUnderLoad: m['genset_runs_under_load'] ?? false,
      voltageFrequencyOk: m['voltage_frequency_ok'] ?? false,
      exhaustOk: m['exhaust_ok'] ?? false,
      groundingBondingOk: m['grounding_bonding_ok'] ?? false,
      controlPanelOk: m['control_panel_ok'] ?? false,
      safetyDevicesOk: m['safety_devices_ok'] ?? false,
      deficienciesDocumented: m['deficiencies_documented'] ?? false,
      loadbankDone: m['loadbank_done'] ?? false,
      atsVerified: m['ats_verified'] ?? false,
      fuelStoredOver1Yr: m['fuel_stored_over_1yr'] ?? false,
      lastServiceDate: m['last_service_date'] ?? '',
      oilFilterChangeDate: m['oil_filter_change_date'] ?? '',
      fuelFilterDate: m['fuel_filter_date'] ?? '',
      coolantFlushDate: m['coolant_flush_date'] ?? '',
      batteryReplaceDate: m['battery_replace_date'] ?? '',
      airFilterDate: m['air_filter_date'] ?? '',
      technicianSignaturePath: m['technician_signature_path'] ?? '',
      technicianSigDate:
          DateTime.tryParse(m['technician_sig_date'] ?? '') ?? DateTime.now(),
      customerSignaturePath: m['customer_signature_path'] ?? '',
      customerSigDate:
          DateTime.tryParse(m['customer_sig_date'] ?? '') ?? DateTime.now(),
      customerName: m['customer_name'] ?? '',
      pdfPath: m['pdf_path'] ?? '',
    );
  }

  Map<String, dynamic> _inspectionToJson(InspectionEntity e) =>
      toSupabaseJson(e);

  /// Serialize to a schema-compliant `public.inspections` row: identity columns
  /// at the top level, all detail fields under the `payload` jsonb column.
  /// Reused by the offline sync queue so the shape stays defined in one place.
  static Map<String, dynamic> toSupabaseJson(InspectionEntity e) {
    return {
      'id': e.id,
      if (SyncContext.tenantId != null) 'tenant_id': SyncContext.tenantId,
      'site_code': e.siteCode,
      'site_grade': e.siteGrade,
      'address': e.address,
      'service_date': e.serviceDate.toIso8601String(),
      'technician_name': e.technicianName,
      'notes': e.notes,
      'pdf_path': e.pdfPath,
      'created_at': e.createdAt.toIso8601String(),
      'updated_at': e.updatedAt.toIso8601String(),
      'client_updated_at': e.updatedAt.toIso8601String(),
      if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
      'payload': inspectionPayload(e),
    };
  }

  /// The non-identity detail fields, stored in the `payload` jsonb column.
  static Map<String, dynamic> inspectionPayload(InspectionEntity e) {
    return {
      'generator_make': e.generatorMake,
      'generator_model': e.generatorModel,
      'generator_serial': e.generatorSerial,
      'generator_kw': e.generatorKw,
      'engine_hours': e.engineHours,
      'fuel_type': e.fuelType,
      'voltage_rating': e.voltageRating,
      'loc_indoors': e.locIndoors,
      'loc_outdoors': e.locOutdoors,
      'loc_roof': e.locRoof,
      'loc_basement': e.locBasement,
      'loc_other': e.locOther,
      'dedicated_room_2hr': e.dedicatedRoom2hr,
      'separate_from_main_service': e.separateFromMainService,
      'area_clear': e.areaClear,
      'labels_estop_visible': e.labelsAndEStopVisible,
      'extinguisher_present': e.extinguisherPresent,
      'fuel_stored_type': e.fuelStoredType,
      'fuel_qty_gallons': e.fuelQtyGallons,
      'fdny_permit': e.fdnyPermit,
      'c92_on_site': e.c92OnSite,
      'gas_cutoff_valve': e.gasCutoffValve,
      'dep_size_kw': e.depSizeKw,
      'dep_registered_cats': e.depRegisteredCats,
      'dep_certificate_operate': e.depCertificateOperate,
      'tier4_compliant': e.tier4Compliant,
      'smoke_or_stack_test': e.smokeOrStackTest,
      'records_kept_5_years': e.recordsKept5Years,
      'emergency_only': e.emergencyOnly,
      'estimated_annual_runtime_hours': e.estimatedAnnualRuntimeHours,
      'fuel_for_6hrs': e.fuelFor6hrs,
      'genset_runs_under_load': e.gensetRunsUnderLoad,
      'voltage_frequency_ok': e.voltageFrequencyOk,
      'exhaust_ok': e.exhaustOk,
      'grounding_bonding_ok': e.groundingBondingOk,
      'control_panel_ok': e.controlPanelOk,
      'safety_devices_ok': e.safetyDevicesOk,
      'deficiencies_documented': e.deficienciesDocumented,
      'loadbank_done': e.loadbankDone,
      'ats_verified': e.atsVerified,
      'fuel_stored_over_1yr': e.fuelStoredOver1Yr,
      'last_service_date': e.lastServiceDate,
      'oil_filter_change_date': e.oilFilterChangeDate,
      'fuel_filter_date': e.fuelFilterDate,
      'coolant_flush_date': e.coolantFlushDate,
      'battery_replace_date': e.batteryReplaceDate,
      'air_filter_date': e.airFilterDate,
      'technician_signature_path': e.technicianSignaturePath,
      'technician_sig_date': e.technicianSigDate.toIso8601String(),
      'customer_signature_path': e.customerSignaturePath,
      'customer_sig_date': e.customerSigDate.toIso8601String(),
      'customer_name': e.customerName,
    };
  }

  NameplateEntity _mapNameplateFromJson(Map<String, dynamic> json) {
    return NameplateEntity(
      id: json['id'].toString(),
      inspectionId: json['inspection_id'].toString(),
      generatorMfr: json['generator_mfr'] ?? '',
      generatorModel: json['generator_model'] ?? '',
      generatorSn: json['generator_sn'] ?? '',
      kva: json['kva'] ?? '',
      kw: json['kw'] ?? '',
      volts: json['volts'] ?? '',
      amps: json['amps'] ?? '',
      phase: json['phase'] ?? '',
      cycles: json['cycles'] ?? '',
      rpm: json['rpm'] ?? '',
      controlMfr: json['control_mfr'] ?? '',
      controlModel: json['control_model'] ?? '',
      controlSn: json['control_sn'] ?? '',
      governorMfr: json['governor_mfr'] ?? '',
      governorModel: json['governor_model'] ?? '',
      governorSn: json['governor_sn'] ?? '',
      regulatorMfr: json['regulator_mfr'] ?? '',
      regulatorModel: json['regulator_model'] ?? '',
      regulatorSn: json['regulator_sn'] ?? '',
      volumeGal: json['volume_gal'] ?? '',
      ullageGal: json['ullage_gal'] ?? '',
      ullage90Gal: json['ullage_90_gal'] ?? '',
      tcVolumeGal: json['tc_volume_gal'] ?? '',
      heightGal: json['height_gal'] ?? '',
      waterGal: json['water_gal'] ?? '',
      waterInches: json['water_inches'] ?? '',
      tempF: json['temp_f'] ?? '',
      time: json['time'] ?? '',
      comments: json['comments'] ?? '',
      deficiencies: json['deficiencies'] ?? '',
    );
  }
}