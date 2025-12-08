import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../storage/hive/hive_boxes.dart';

/// Offline-first backup/export helpers.
/// - Export a single inspection (JSON) to app docs or a chosen dir
/// - Export all inspections + load-test rows into a single JSON file
/// - Copy PDFs alongside JSON (Android/desktop; web returns bytes you can upload)
class BackupService {
  /// Export a single inspection + its load-test rows to a JSON file.
  /// Returns the file path (mobile/desktop) or throws on web (use [exportAllAsJsonBytes] on web).
  Future<String> exportInspectionAsJsonFile(Inspection ins, {Directory? targetDir}) async {
    final payload = await _buildInspectionPayload(ins.id);
    final dir = targetDir ?? await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/inspection-${ins.id}.json');
    await f.writeAsBytes(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)), flush: true);
    return f.path;
  }

  /// Export all inspections to one JSON file. Returns the file path (non-web).
  Future<String> exportAllAsJsonFile({Directory? targetDir}) async {
    final list = <Map<String, dynamic>>[];
    for (final ins in HiveBoxes.inspections.values) {
      list.add(await _buildInspectionPayload(ins.id));
    }
    final root = {
      'exportId': const Uuid().v4(),
      'exportedAt': DateTime.now().toIso8601String(),
      'inspections': list,
    };
    final dir = targetDir ?? await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/inspections-export-${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsBytes(utf8.encode(const JsonEncoder.withIndent('  ').convert(root)), flush: true);
    return f.path;
  }

  /// Web-friendly: returns bytes for all-inspections JSON (you can upload or trigger a download)
  Future<List<int>> exportAllAsJsonBytes() async {
    final list = <Map<String, dynamic>>[];
    for (final ins in HiveBoxes.inspections.values) {
      list.add(await _buildInspectionPayload(ins.id));
    }
    final root = {
      'exportId': const Uuid().v4(),
      'exportedAt': DateTime.now().toIso8601String(),
      'inspections': list,
    };
    return utf8.encode(jsonEncode(root));
  }

  /// Copy all generated PDFs into a given directory (Android/desktop)
  Future<void> copyAllPdfsTo(Directory target) async {
    if (kIsWeb) {
      throw UnsupportedError('copyAllPdfsTo is not supported on web');
    }
    if (!target.existsSync()) target.createSync(recursive: true);
    for (final ins in HiveBoxes.inspections.values) {
      final p = ins.pdfPath;
      if (p.isEmpty) continue;
      final src = File(p);
      if (src.existsSync()) {
        final out = File('${target.path}/inspection-${ins.id}.pdf');
        await out.writeAsBytes(await src.readAsBytes(), flush: true);
      }
    }
  }

  /// Build a nested JSON object for a single inspection with its load-test rows.
  Future<Map<String, dynamic>> _buildInspectionPayload(String inspectionId) async {
    final ins = HiveBoxes.inspections.get(inspectionId);
    if (ins == null) throw StateError('Inspection $inspectionId not found');

    final rows = HiveBoxes.loadTests.values
        .where((r) => r.inspectionId == inspectionId)
        .toList()
      ..sort((a, b) => a.stepIndex.compareTo(b.stepIndex));

    return {
      'inspection': _inspectionToMap(ins),
      'loadTestRecords': rows.map((r) => r.toJson()).toList(),
      'pdfPath': ins.pdfPath,
    };
  }

  Map<String, dynamic> _inspectionToMap(Inspection ins) => {
    'id': ins.id,
    'createdAt': ins.createdAt.toIso8601String(),
    'siteCode': ins.siteCode,
    'siteGrade': ins.siteGrade,
    'address': ins.address,
    'serviceDate': ins.serviceDate.toIso8601String(),
    'technicianName': ins.technicianName,
    'generatorMake': ins.generatorMake,
    'generatorModel': ins.generatorModel,
    'generatorSerial': ins.generatorSerial,
    'generatorKw': ins.generatorKw,
    'engineHours': ins.engineHours,
    'fuelType': ins.fuelType,
    'voltageRating': ins.voltageRating,
    'locIndoors': ins.locIndoors,
    'locOutdoors': ins.locOutdoors,
    'locRoof': ins.locRoof,
    'locBasement': ins.locBasement,
    'locOther': ins.locOther,
    'dedicatedRoom2hr': ins.dedicatedRoom2hr,
    'separateFromMainService': ins.separateFromMainService,
    'areaClear': ins.areaClear,
    'labelsAndEStopVisible': ins.labelsAndEStopVisible,
    'extinguisherPresent': ins.extinguisherPresent,
    'fuelStoredType': ins.fuelStoredType,
    'fuelQtyGallons': ins.fuelQtyGallons,
    'fdnyPermit': ins.fdnyPermit,
    'c92OnSite': ins.c92OnSite,
    'gasCutoffValve': ins.gasCutoffValve,
    'depSizeKw': ins.depSizeKw,
    'depRegisteredCats': ins.depRegisteredCats,
    'depCertificateOperate': ins.depCertificateOperate,
    'tier4Compliant': ins.tier4Compliant,
    'smokeOrStackTest': ins.smokeOrStackTest,
    'recordsKept5Years': ins.recordsKept5Years,
    'emergencyOnly': ins.emergencyOnly,
    'estimatedAnnualRuntimeHours': ins.estimatedAnnualRuntimeHours,
    'fuelFor6hrs': ins.fuelFor6hrs,
    'notes': ins.notes,
    'gensetRunsUnderLoad': ins.gensetRunsUnderLoad,
    'voltageFrequencyOk': ins.voltageFrequencyOk,
    'exhaustOk': ins.exhaustOk,
    'groundingBondingOk': ins.groundingBondingOk,
    'controlPanelOk': ins.controlPanelOk,
    'safetyDevicesOk': ins.safetyDevicesOk,
    'deficienciesDocumented': ins.deficienciesDocumented,
    'loadbankDone': ins.loadbankDone,
    'atsVerified': ins.atsVerified,
    'fuelStoredOver1Yr': ins.fuelStoredOver1Yr,
    'lastServiceDate': ins.lastServiceDate,
    'oilFilterChangeDate': ins.oilFilterChangeDate,
    'fuelFilterDate': ins.fuelFilterDate,
    'coolantFlushDate': ins.coolantFlushDate,
    'batteryReplaceDate': ins.batteryReplaceDate,
    'airFilterDate': ins.airFilterDate,
    'technicianSignaturePath': ins.technicianSignaturePath,
    'technicianSigDate': ins.technicianSigDate.toIso8601String(),
    'customerSignaturePath': ins.customerSignaturePath,
    'customerSigDate': ins.customerSigDate.toIso8601String(),
    'customerName': ins.customerName,
    'pdfPath': ins.pdfPath,
  };
}
