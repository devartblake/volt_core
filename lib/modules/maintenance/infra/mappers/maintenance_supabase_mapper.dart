import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../models/maintenance_record.dart';

/// Supabase tables that mirror a [MaintenanceRecord].
///
/// The schema splits maintenance into an identity row (`maintenance_jobs`) and a
/// detail row (`maintenance_records.data` jsonb) linked by `job_id`. The app has
/// a single flat record, so each save writes both rows keyed by the record id
/// (job.id == record.id == records.job_id).
const String kMaintenanceJobsTable = 'maintenance_jobs';
const String kMaintenanceRecordsTable = 'maintenance_records';

/// Identity row for `public.maintenance_jobs`.
///
/// `inspection_id` is intentionally kept only in the detail jsonb (not on the
/// job) to avoid a foreign-key failure when the referenced inspection hasn't
/// been pushed to the cloud yet.
Map<String, dynamic> maintenanceJobRow(MaintenanceRecord r) {
  return {
    'id': r.id,
    if (SyncContext.tenantId != null) 'tenant_id': SyncContext.tenantId,
    'title': r.siteCode.isNotEmpty ? 'Site ${r.siteCode}' : 'Maintenance Job',
    'site_code': r.siteCode,
    'address': r.address,
    'technician_name': r.technicianName,
    if (r.dateOfService != null)
      'date_of_service': r.dateOfService!.toIso8601String(),
    'status': r.completed ? 'completed' : 'draft',
    'is_completed': r.completed,
    if (r.completed) 'completed_at': r.updatedAt.toIso8601String(),
    'requires_follow_up': r.requiresFollowUp,
    if (r.followUpNotes != null) 'follow_up_notes': r.followUpNotes,
    if (r.generalNotes != null) 'general_notes': r.generalNotes,
    'created_at': r.createdAt.toIso8601String(),
    'updated_at': r.updatedAt.toIso8601String(),
    'client_updated_at': r.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

/// Detail row for `public.maintenance_records` (all fields under `data` jsonb).
Map<String, dynamic> maintenanceRecordRow(MaintenanceRecord r) {
  return {
    'id': r.id,
    if (SyncContext.tenantId != null) 'tenant_id': SyncContext.tenantId,
    'job_id': r.id,
    'data': maintenanceRecordData(r),
    'created_at': r.createdAt.toIso8601String(),
    'updated_at': r.updatedAt.toIso8601String(),
    'client_updated_at': r.updatedAt.toIso8601String(),
  };
}

/// The full maintenance detail, stored in `maintenance_records.data` (jsonb).
///
/// Transient fields (signature bytes) are intentionally omitted â the images
/// themselves are backed up to Supabase Storage via the file backup queue.
Map<String, dynamic> maintenanceRecordData(MaintenanceRecord r) {
  return {
    'inspection_id': r.inspectionId,
    'site_code': r.siteCode,
    'address': r.address,
    'date_of_service': r.dateOfService?.toIso8601String(),
    'technician_name': r.technicianName,
    'generator_make': r.generatorMake,
    'generator_model': r.generatorModel,
    'generator_serial': r.generatorSerial,
    'generator_kw': r.generatorKw,
    'engine_hours': r.engineHours,
    'fuel_type': r.fuelType,
    'last_fuel_delivery_date': r.lastFuelDeliveryDate,
    'voltage_rating': r.voltageRating,
    'generator_location': r.generatorLocation,
    'generator_location_other': r.generatorLocationOther,
    'enclosure_damaged': r.enclosureDamaged,
    'enclosure_intact': r.enclosureIntact,
    'no_enclosure': r.noEnclosure,
    'visible_damage_or_leaks': r.visibleDamageOrLeaks,
    'area_clear_of_hazards': r.areaClearOfHazards,
    'warning_labels_visible': r.warningLabelsVisible,
    'fire_extinguisher_present': r.fireExtinguisherPresent,
    'battery_needs_replace': r.batteryNeedsReplace,
    'battery_recently_replaced': r.batteryRecentlyReplaced,
    'battery_mfg_date': r.batteryMfgDate,
    'battery_part_no': r.batteryPartNo,
    'battery_type': r.batteryType,
    'air_filter_needs_replace': r.airFilterNeedsReplace,
    'air_filter_recently_replaced': r.airFilterRecentlyReplaced,
    'air_filter_last_replaced_date': r.airFilterLastReplacedDate,
    'air_filter_part_no': r.airFilterPartNo,
    'coolant_level': r.coolantLevel,
    'coolant_color': r.coolantColor,
    'coolant_hoses_compromised': r.coolantHosesCompromised,
    'coolant_hoses_recommend_change': r.coolantHosesRecommendChange,
    'coolant_hoses_info': r.coolantHosesInfo,
    'fuel_hoses_compromised': r.fuelHosesCompromised,
    'fuel_hoses_recommend_change': r.fuelHosesRecommendChange,
    'fuel_hoses_info': r.fuelHosesInfo,
    'air_intake_hoses_compromised': r.airIntakeHosesCompromised,
    'air_intake_hoses_recommend_change': r.airIntakeHosesRecommendChange,
    'air_intake_hoses_info': r.airIntakeHosesInfo,
    'oil_hoses_compromised': r.oilHosesCompromised,
    'oil_hoses_recommend_change': r.oilHosesRecommendChange,
    'oil_hoses_info': r.oilHosesInfo,
    'additional_hoses_compromised': r.additionalHosesCompromised,
    'additional_hoses_recommend_change': r.additionalHosesRecommendChange,
    'additional_hoses_info': r.additionalHosesInfo,
    'can_lube': r.canLube,
    'can_lube_part_no': r.canLubePartNo,
    'can_fuel': r.canFuel,
    'can_fuel_part_no': r.canFuelPartNo,
    'can_water_sep': r.canWaterSep,
    'can_water_sep_part_no': r.canWaterSepPartNo,
    'can_oil': r.canOil,
    'can_oil_part_no': r.canOilPartNo,
    'can_other1': r.canOther1,
    'can_other1_label': r.canOther1Label,
    'can_other1_part_no': r.canOther1PartNo,
    'can_other2': r.canOther2,
    'can_other2_label': r.canOther2Label,
    'can_other2_part_no': r.canOther2PartNo,
    'oil_filter_changed': r.oilFilterChanged,
    'oil_filter_notes': r.oilFilterNotes,
    'fuel_filter_replaced': r.fuelFilterReplaced,
    'fuel_filter_notes': r.fuelFilterNotes,
    'coolant_flushed': r.coolantFlushed,
    'coolant_notes': r.coolantNotes,
    'battery_replaced': r.batteryReplaced,
    'battery_notes': r.batteryNotes,
    'air_filter_replaced': r.airFilterReplaced,
    'air_filter_notes': r.airFilterNotes,
    'belts_hoses_replaced': r.beltsHosesReplaced,
    'belts_hoses_notes': r.beltsHosesNotes,
    'block_heater_tested': r.blockHeaterTested,
    'block_heater_notes': r.blockHeaterNotes,
    'racor_serviced': r.racorServiced,
    'racor_notes': r.racorNotes,
    'ats_controller_inspected': r.atsControllerInspected,
    'ats_controller_notes': r.atsControllerNotes,
    'cdvr_programmed': r.cdvrProgrammed,
    'cdvr_notes': r.cdvrNotes,
    'undervoltage_repaired': r.undervoltageRepaired,
    'undervoltage_notes': r.undervoltageNotes,
    'hazmat_removed': r.hazmatRemoved,
    'hazmat_notes': r.hazmatNotes,
    'service_observations': r.serviceObservations,
    'post_verify_runs_under_load': r.postVerifyRunsUnderLoad,
    'post_check_volt_freq': r.postCheckVoltFreq,
    'post_inspect_exhaust': r.postInspectExhaust,
    'post_verify_grounding': r.postVerifyGrounding,
    'post_check_control_panel': r.postCheckControlPanel,
    'post_ensure_safety_devices': r.postEnsureSafetyDevices,
    'post_document_deficiencies': r.postDocumentDeficiencies,
    'post_loadbank_test': r.postLoadbankTest,
    'post_ats_functionality': r.postAtsFunctionality,
    'fuel_stored_long': r.fuelStoredLong,
    'parts_oil_type_qty': r.partsOilTypeQty,
    'parts_coolant_type_qty': r.partsCoolantTypeQty,
    'parts_filter_types': r.partsFilterTypes,
    'parts_battery_type_date': r.partsBatteryTypeDate,
    'parts_belts_hoses_replaced': r.partsBeltsHosesReplaced,
    'parts_block_heater_wattage': r.partsBlockHeaterWattage,
    'parts_cdvr_serial': r.partsCdvrSerial,
    'technician_signature_name': r.technicianSignatureName,
    'technician_signature_date': r.technicianSignatureDate?.toIso8601String(),
    'customer_signature_name': r.customerSignatureName,
    'customer_signature_date': r.customerSignatureDate?.toIso8601String(),
    'general_notes': r.generalNotes,
    'completed': r.completed,
    'requires_follow_up': r.requiresFollowUp,
    'follow_up_notes': r.followUpNotes,
    'technician_signature_path': r.technicianSignaturePath,
    'customer_signature_path': r.customerSignaturePath,
  };
}

/// Restores a full Hive record from the two Supabase rows used by maintenance
/// sync. Keeping this inverse alongside [maintenanceRecordData] prevents a
/// cache reset from turning a valid cloud record into a blank detail page.
MaintenanceRecord maintenanceRecordFromSupabaseRows({
  required Map<String, dynamic> job,
  Map<String, dynamic>? details,
}) {
  final data = details?['data'] is Map
      ? Map<String, dynamic>.from(details!['data'] as Map)
      : const <String, dynamic>{};
  final record = MaintenanceRecord(
    id: _text(job['id']),
    createdAt: _date(job['created_at']) ?? DateTime.now(),
    updatedAt: _date(job['updated_at']) ?? DateTime.now(),
  )
  ..inspectionId = _nullableText(data['inspection_id'])
  ..siteCode = _text(data['site_code'])
  ..address = _text(data['address'])
  ..dateOfService = _date(data['date_of_service'])
  ..technicianName = _text(data['technician_name'])
  ..generatorMake = _text(data['generator_make'])
  ..generatorModel = _text(data['generator_model'])
  ..generatorSerial = _text(data['generator_serial'])
  ..generatorKw = _text(data['generator_kw'])
  ..engineHours = _text(data['engine_hours'])
  ..fuelType = _text(data['fuel_type'])
  ..lastFuelDeliveryDate = _text(data['last_fuel_delivery_date'])
  ..voltageRating = _text(data['voltage_rating'])
  ..generatorLocation = _text(data['generator_location'])
  ..generatorLocationOther = _text(data['generator_location_other'])
  ..enclosureDamaged = _bool(data['enclosure_damaged'])
  ..enclosureIntact = _bool(data['enclosure_intact'])
  ..noEnclosure = _bool(data['no_enclosure'])
  ..visibleDamageOrLeaks = _bool(data['visible_damage_or_leaks'])
  ..areaClearOfHazards = _bool(data['area_clear_of_hazards'])
  ..warningLabelsVisible = _bool(data['warning_labels_visible'])
  ..fireExtinguisherPresent = _bool(data['fire_extinguisher_present'])
  ..batteryNeedsReplace = _bool(data['battery_needs_replace'])
  ..batteryRecentlyReplaced = _bool(data['battery_recently_replaced'])
  ..batteryMfgDate = _text(data['battery_mfg_date'])
  ..batteryPartNo = _text(data['battery_part_no'])
  ..batteryType = _text(data['battery_type'])
  ..airFilterNeedsReplace = _bool(data['air_filter_needs_replace'])
  ..airFilterRecentlyReplaced = _bool(data['air_filter_recently_replaced'])
  ..airFilterLastReplacedDate = _text(data['air_filter_last_replaced_date'])
  ..airFilterPartNo = _text(data['air_filter_part_no'])
  ..coolantLevel = _text(data['coolant_level'])
  ..coolantColor = _text(data['coolant_color'])
  ..coolantHosesCompromised = _bool(data['coolant_hoses_compromised'])
  ..coolantHosesRecommendChange = _bool(data['coolant_hoses_recommend_change'])
  ..coolantHosesInfo = _text(data['coolant_hoses_info'])
  ..fuelHosesCompromised = _bool(data['fuel_hoses_compromised'])
  ..fuelHosesRecommendChange = _bool(data['fuel_hoses_recommend_change'])
  ..fuelHosesInfo = _text(data['fuel_hoses_info'])
  ..airIntakeHosesCompromised = _bool(data['air_intake_hoses_compromised'])
  ..airIntakeHosesRecommendChange = _bool(data['air_intake_hoses_recommend_change'])
  ..airIntakeHosesInfo = _text(data['air_intake_hoses_info'])
  ..oilHosesCompromised = _bool(data['oil_hoses_compromised'])
  ..oilHosesRecommendChange = _bool(data['oil_hoses_recommend_change'])
  ..oilHosesInfo = _text(data['oil_hoses_info'])
  ..additionalHosesCompromised = _bool(data['additional_hoses_compromised'])
  ..additionalHosesRecommendChange = _bool(data['additional_hoses_recommend_change'])
  ..additionalHosesInfo = _text(data['additional_hoses_info'])
  ..canLube = _bool(data['can_lube'])
  ..canLubePartNo = _text(data['can_lube_part_no'])
  ..canFuel = _bool(data['can_fuel'])
  ..canFuelPartNo = _text(data['can_fuel_part_no'])
  ..canWaterSep = _bool(data['can_water_sep'])
  ..canWaterSepPartNo = _text(data['can_water_sep_part_no'])
  ..canOil = _bool(data['can_oil'])
  ..canOilPartNo = _text(data['can_oil_part_no'])
  ..canOther1 = _bool(data['can_other1'])
  ..canOther1Label = _text(data['can_other1_label'])
  ..canOther1PartNo = _text(data['can_other1_part_no'])
  ..canOther2 = _bool(data['can_other2'])
  ..canOther2Label = _text(data['can_other2_label'])
  ..canOther2PartNo = _text(data['can_other2_part_no'])
  ..oilFilterChanged = _bool(data['oil_filter_changed'])
  ..oilFilterNotes = _text(data['oil_filter_notes'])
  ..fuelFilterReplaced = _bool(data['fuel_filter_replaced'])
  ..fuelFilterNotes = _text(data['fuel_filter_notes'])
  ..coolantFlushed = _bool(data['coolant_flushed'])
  ..coolantNotes = _text(data['coolant_notes'])
  ..batteryReplaced = _bool(data['battery_replaced'])
  ..batteryNotes = _text(data['battery_notes'])
  ..airFilterReplaced = _bool(data['air_filter_replaced'])
  ..airFilterNotes = _text(data['air_filter_notes'])
  ..beltsHosesReplaced = _bool(data['belts_hoses_replaced'])
  ..beltsHosesNotes = _text(data['belts_hoses_notes'])
  ..blockHeaterTested = _bool(data['block_heater_tested'])
  ..blockHeaterNotes = _text(data['block_heater_notes'])
  ..racorServiced = _bool(data['racor_serviced'])
  ..racorNotes = _text(data['racor_notes'])
  ..atsControllerInspected = _bool(data['ats_controller_inspected'])
  ..atsControllerNotes = _text(data['ats_controller_notes'])
  ..cdvrProgrammed = _bool(data['cdvr_programmed'])
  ..cdvrNotes = _text(data['cdvr_notes'])
  ..undervoltageRepaired = _bool(data['undervoltage_repaired'])
  ..undervoltageNotes = _text(data['undervoltage_notes'])
  ..hazmatRemoved = _bool(data['hazmat_removed'])
  ..hazmatNotes = _text(data['hazmat_notes'])
  ..serviceObservations = _text(data['service_observations'])
  ..postVerifyRunsUnderLoad = _bool(data['post_verify_runs_under_load'])
  ..postCheckVoltFreq = _bool(data['post_check_volt_freq'])
  ..postInspectExhaust = _bool(data['post_inspect_exhaust'])
  ..postVerifyGrounding = _bool(data['post_verify_grounding'])
  ..postCheckControlPanel = _bool(data['post_check_control_panel'])
  ..postEnsureSafetyDevices = _bool(data['post_ensure_safety_devices'])
  ..postDocumentDeficiencies = _bool(data['post_document_deficiencies'])
  ..postLoadbankTest = _bool(data['post_loadbank_test'])
  ..postAtsFunctionality = _bool(data['post_ats_functionality'])
  ..fuelStoredLong = _bool(data['fuel_stored_long'])
  ..partsOilTypeQty = _text(data['parts_oil_type_qty'])
  ..partsCoolantTypeQty = _text(data['parts_coolant_type_qty'])
  ..partsFilterTypes = _text(data['parts_filter_types'])
  ..partsBatteryTypeDate = _text(data['parts_battery_type_date'])
  ..partsBeltsHosesReplaced = _text(data['parts_belts_hoses_replaced'])
  ..partsBlockHeaterWattage = _text(data['parts_block_heater_wattage'])
  ..partsCdvrSerial = _text(data['parts_cdvr_serial'])
  ..technicianSignatureName = _text(data['technician_signature_name'])
  ..technicianSignatureDate = _date(data['technician_signature_date'])
  ..customerSignatureName = _text(data['customer_signature_name'])
  ..customerSignatureDate = _date(data['customer_signature_date'])
  ..generalNotes = _nullableText(data['general_notes'])
  ..completed = _bool(data['completed'])
  ..requiresFollowUp = _bool(data['requires_follow_up'])
  ..followUpNotes = _nullableText(data['follow_up_notes'])
  ..technicianSignaturePath = _nullableText(data['technician_signature_path'])
  ..customerSignaturePath = _nullableText(data['customer_signature_path']);
  return record;
}

String _text(Object? value) => value?.toString() ?? '';

String? _nullableText(Object? value) => value == null ? null : value.toString();

bool _bool(Object? value) =>
    value is bool ? value : value?.toString().toLowerCase() == 'true';

DateTime? _date(Object? value) => switch (value) {
  DateTime value => value,
  String value => DateTime.tryParse(value),
  _ => null,
};

/// Queue the two upserts (job identity + detail) for cloud sync. The job row is
/// enqueued first so it exists before the FK-linked detail row is pushed.
Future<void> enqueueMaintenanceSync(MaintenanceRecord r) async {
  await SyncService.instance.enqueueUpsert(
    table: kMaintenanceJobsTable,
    id: r.id,
    payload: maintenanceJobRow(r),
  );
  await SyncService.instance.enqueueUpsert(
    table: kMaintenanceRecordsTable,
    id: r.id,
    payload: maintenanceRecordRow(r),
  );
}

/// Queue a delete. Removing the job cascades to `maintenance_records` (and
/// parts / attachments) via the schema's ON DELETE CASCADE.
Future<void> enqueueMaintenanceDelete(String id) {
  return SyncService.instance.enqueueDelete(table: kMaintenanceJobsTable, id: id);
}
