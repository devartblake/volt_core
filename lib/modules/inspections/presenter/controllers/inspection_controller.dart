import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/hive/hive_boxes.dart';
import '../../infra/models/inspection.dart';
import '../../../load_test/infra/models/load_test_record.dart';
import '../../external/drivers/inspection_export_driver.dart';

/// Public provider to interact with inspections + load-test rows
final inspectionControllerProvider =
Provider<InspectionController>((ref) {
  final exportDriver =
  ref.read(inspectionExportDriverProvider);
  return InspectionController(
    ref: ref,
    exportDriver: exportDriver,
  );
});

class InspectionController {
  InspectionController({
    required this.ref,
    required this.exportDriver,
  });

  final Ref ref;
  final InspectionExportDriver exportDriver;

  /// Returns all inspections (sorted desc by createdAt) from Hive.
  List<Inspection> listInspections() {
    final values =
    HiveBoxes.inspections.values.toList();
    values.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );
    return values;
  }

  /// Returns load-test rows for the given inspection, sorted by stepIndex
  List<LoadTestRecord> listLoadTests(String inspectionId) {
    final all = HiveBoxes.loadTests.values
        .where((r) => r.inspectionId == inspectionId)
        .toList();
    all.sort((a, b) => a.stepIndex.compareTo(b.stepIndex));
    return all;
  }

  /// Create or update an Inspection draft in Hive
  Future<void> upsertInspection(Inspection model) async {
    await HiveBoxes.inspections.put(model.id, model);
  }

  /// Save & export: persists, generates PDF, exports optional, emails
  Future<void> saveAndExport(
      BuildContext context,
      Inspection model,
      ) async {
    await exportDriver.saveAndExport(model, context);
  }

  /// Add a blank load-test row at the end
  Future<LoadTestRecord> addLoadTestRow(
      String inspectionId, {
        int? loadPercent,
        int? minutes,
      }) async {
    final id = const Uuid().v4();
    final nextIndex = listLoadTests(inspectionId).length;
    final rec = LoadTestRecord(
      id: id,
      inspectionId: inspectionId,
      stepIndex: nextIndex,
      loadPercent: loadPercent ?? 0,
      durationMinutes: minutes ?? 0,
    );
    await HiveBoxes.loadTests.put(rec.id, rec);
    return rec;
  }

  /// Update a load-test row
  Future<void> updateLoadTestRow(
      LoadTestRecord rec) async {
    await rec.save();
  }

  /// Delete a single load-test row; optionally re-index the remaining items
  Future<void> deleteLoadTestRow(
      String id, {
        bool reindex = true,
      }) async {
    final rec = HiveBoxes.loadTests.get(id);
    if (rec == null) return;
    final inspId = rec.inspectionId;
    await HiveBoxes.loadTests.delete(id);

    if (reindex) {
      final items = listLoadTests(inspId);
      for (var i = 0; i < items.length; i++) {
        if (items[i].stepIndex != i) {
          items[i].stepIndex = i;
          await items[i].save();
        }
      }
    }
  }

  /// Duplicate an inspection (without copying load-test rows by default)
  Future<Inspection> duplicateInspection(
      Inspection src, {
        bool copyLoadRows = false,
      }) async {
    final dup = Inspection(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      siteCode: src.siteCode,
      siteGrade: src.siteGrade,
      address: src.address,
      serviceDate: DateTime.now(),
      technicianName: src.technicianName,
      generatorMake: src.generatorMake,
      generatorModel: src.generatorModel,
      generatorSerial: src.generatorSerial,
      generatorKw: src.generatorKw,
      engineHours: src.engineHours,
      fuelType: src.fuelType,
      voltageRating: src.voltageRating,
      locIndoors: src.locIndoors,
      locOutdoors: src.locOutdoors,
      locRoof: src.locRoof,
      locBasement: src.locBasement,
      locOther: src.locOther,
      dedicatedRoom2hr: src.dedicatedRoom2hr,
      separateFromMainService:
      src.separateFromMainService,
      areaClear: src.areaClear,
      labelsAndEStopVisible:
      src.labelsAndEStopVisible,
      extinguisherPresent: src.extinguisherPresent,
      fuelStoredType: src.fuelStoredType,
      fuelQtyGallons: src.fuelQtyGallons,
      fdnyPermit: src.fdnyPermit,
      c92OnSite: src.c92OnSite,
      gasCutoffValve: src.gasCutoffValve,
      depSizeKw: src.depSizeKw,
      depRegisteredCats: src.depRegisteredCats,
      depCertificateOperate:
      src.depCertificateOperate,
      tier4Compliant: src.tier4Compliant,
      smokeOrStackTest: src.smokeOrStackTest,
      recordsKept5Years: src.recordsKept5Years,
      emergencyOnly: src.emergencyOnly,
      estimatedAnnualRuntimeHours:
      src.estimatedAnnualRuntimeHours,
      fuelFor6hrs: src.fuelFor6hrs,
      notes: src.notes,
      gensetRunsUnderLoad: src.gensetRunsUnderLoad,
      voltageFrequencyOk: src.voltageFrequencyOk,
      exhaustOk: src.exhaustOk,
      groundingBondingOk: src.groundingBondingOk,
      controlPanelOk: src.controlPanelOk,
      safetyDevicesOk: src.safetyDevicesOk,
      deficienciesDocumented:
      src.deficienciesDocumented,
      loadbankDone: src.loadbankDone,
      atsVerified: src.atsVerified,
      fuelStoredOver1Yr: src.fuelStoredOver1Yr,
      lastServiceDate: src.lastServiceDate,
      oilFilterChangeDate: src.oilFilterChangeDate,
      fuelFilterDate: src.fuelFilterDate,
      coolantFlushDate: src.coolantFlushDate,
      batteryReplaceDate: src.batteryReplaceDate,
      airFilterDate: src.airFilterDate,
      technicianSignaturePath:
      src.technicianSignaturePath,
      technicianSigDate: DateTime.now(),
      customerSignaturePath:
      src.customerSignaturePath,
      customerSigDate: DateTime.now(),
      customerName: src.customerName,
      pdfPath: '',
    );
    await HiveBoxes.inspections.put(dup.id, dup);

    if (copyLoadRows) {
      final rows = listLoadTests(src.id);
      for (final r in rows) {
        final nr = r.copyWith(
          id: const Uuid().v4(),
          inspectionId: dup.id,
        );
        await HiveBoxes.loadTests.put(nr.id, nr);
      }
    }
    return dup;
  }
}
