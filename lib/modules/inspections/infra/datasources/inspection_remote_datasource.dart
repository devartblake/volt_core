import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Adjust keys as needed to match DB
    return InspectionEntity(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ??
          DateTime.now(),
      siteCode: json['site_code'] ?? '',
      siteGrade: json['site_grade'] ?? '',
      address: json['address'] ?? '',
      serviceDate: DateTime.tryParse(json['service_date'] ?? '') ??
          DateTime.now(),
      technicianName: json['technician_name'] ?? '',
      generatorMake: json['generator_make'] ?? '',
      generatorModel: json['generator_model'] ?? '',
      generatorSerial: json['generator_serial'] ?? '',
      generatorKw: json['generator_kw'] ?? '',
      engineHours: json['engine_hours'] ?? '',
      fuelType: json['fuel_type'] ?? '',
      voltageRating: json['voltage_rating'] ?? '',
      locIndoors: json['loc_indoors'] ?? false,
      locOutdoors: json['loc_outdoors'] ?? false,
      locRoof: json['loc_roof'] ?? false,
      locBasement: json['loc_basement'] ?? false,
      locOther: json['loc_other'] ?? '',
      dedicatedRoom2hr: json['dedicated_room_2hr'] ?? false,
      separateFromMainService:
      json['separate_from_main_service'] ?? false,
      areaClear: json['area_clear'] ?? false,
      labelsAndEStopVisible:
      json['labels_estop_visible'] ?? false,
      extinguisherPresent: json['extinguisher_present'] ?? false,
      fuelStoredType: json['fuel_stored_type'] ?? '',
      fuelQtyGallons: json['fuel_qty_gallons'] ?? '',
      fdnyPermit: json['fdny_permit'] ?? 'Unknown',
      c92OnSite: json['c92_on_site'] ?? 'Unknown',
      gasCutoffValve: json['gas_cutoff_valve'] ?? 'N/A',
      depSizeKw: json['dep_size_kw'] ?? '',
      depRegisteredCats: json['dep_registered_cats'] ?? 'Unknown',
      depCertificateOperate:
      json['dep_certificate_operate'] ?? 'Unknown',
      tier4Compliant: json['tier4_compliant'] ?? 'Unknown',
      smokeOrStackTest: json['smoke_or_stack_test'] ?? 'Unknown',
      recordsKept5Years: json['records_kept_5_years'] ?? false,
      emergencyOnly: json['emergency_only'] ?? true,
      estimatedAnnualRuntimeHours:
      json['estimated_annual_runtime_hours'] ?? '',
      fuelFor6hrs: json['fuel_for_6hrs'] ?? 'N/A',
      notes: json['notes'] ?? '',
      gensetRunsUnderLoad: json['genset_runs_under_load'] ?? false,
      voltageFrequencyOk: json['voltage_frequency_ok'] ?? false,
      exhaustOk: json['exhaust_ok'] ?? false,
      groundingBondingOk:
      json['grounding_bonding_ok'] ?? false,
      controlPanelOk: json['control_panel_ok'] ?? false,
      safetyDevicesOk: json['safety_devices_ok'] ?? false,
      deficienciesDocumented:
      json['deficiencies_documented'] ?? false,
      loadbankDone: json['loadbank_done'] ?? false,
      atsVerified: json['ats_verified'] ?? false,
      fuelStoredOver1Yr: json['fuel_stored_over_1yr'] ?? false,
      lastServiceDate: json['last_service_date'] ?? '',
      oilFilterChangeDate: json['oil_filter_change_date'] ?? '',
      fuelFilterDate: json['fuel_filter_date'] ?? '',
      coolantFlushDate: json['coolant_flush_date'] ?? '',
      batteryReplaceDate: json['battery_replace_date'] ?? '',
      airFilterDate: json['air_filter_date'] ?? '',
      technicianSignaturePath:
      json['technician_signature_path'] ?? '',
      technicianSigDate:
      DateTime.tryParse(json['technician_sig_date'] ?? '') ??
          DateTime.now(),
      customerSignaturePath:
      json['customer_signature_path'] ?? '',
      customerSigDate:
      DateTime.tryParse(json['customer_sig_date'] ?? '') ??
          DateTime.now(),
      customerName: json['customer_name'] ?? '',
      pdfPath: json['pdf_path'] ?? '',
    );
  }

  Map<String, dynamic> _inspectionToJson(InspectionEntity e) {
    return {
      'id': e.id,
      'created_at': e.createdAt.toIso8601String(),
      'site_code': e.siteCode,
      'site_grade': e.siteGrade,
      'address': e.address,
      'service_date': e.serviceDate.toIso8601String(),
      'technician_name': e.technicianName,
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
      'estimated_annual_runtime_hours':
      e.estimatedAnnualRuntimeHours,
      'fuel_for_6hrs': e.fuelFor6hrs,
      'notes': e.notes,
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
      'technician_sig_date':
      e.technicianSigDate.toIso8601String(),
      'customer_signature_path': e.customerSignaturePath,
      'customer_sig_date':
      e.customerSigDate.toIso8601String(),
      'customer_name': e.customerName,
      'pdf_path': e.pdfPath,
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