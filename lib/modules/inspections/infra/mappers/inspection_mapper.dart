import '../../domain/entities/inspection_entity.dart';
import '../models/inspection.dart' as infra;

/// Temporary mapper between the domain InspectionEntity
/// and the old Hive-backed infra Inspection model used by PdfService.
class InspectionMapper {
  /// Domain → Infra (Hive model) for PDF generation.
  static infra.Inspection fromEntity(InspectionEntity e) {
    return infra.Inspection(
      id: e.id,
      createdAt: e.createdAt ?? DateTime.now(),

      // Basic site / meta
      siteCode: e.siteCode ?? '',
      siteGrade: e.siteGrade ?? '',
      address: e.address ?? '',
      serviceDate: e.serviceDate ?? DateTime.now(),
      technicianName: e.technicianName ?? '',

      // Generator info
      generatorMake: e.generatorMake ?? '',
      generatorModel: e.generatorModel ?? '',
      generatorSerial: e.generatorSerial ?? '',
      generatorKw: e.generatorKw ?? '',
      engineHours: e.engineHours ?? '',
      fuelType: e.fuelType ?? '',
      voltageRating: e.voltageRating ?? '',

      // Location & safety
      locIndoors: e.locIndoors ?? false,
      locOutdoors: e.locOutdoors ?? false,
      locRoof: e.locRoof ?? false,
      locBasement: e.locBasement ?? false,
      locOther: e.locOther ?? '',
      dedicatedRoom2hr: e.dedicatedRoom2hr ?? false,
      separateFromMainService: e.separateFromMainService ?? false,
      areaClear: e.areaClear ?? false,
      labelsAndEStopVisible: e.labelsAndEStopVisible ?? false,
      extinguisherPresent: e.extinguisherPresent ?? false,

      // FDNY / DEP
      fuelStoredType: e.fuelStoredType ?? '',
      fuelQtyGallons: e.fuelQtyGallons ?? '',
      fdnyPermit: e.fdnyPermit ?? 'Unknown',
      c92OnSite: e.c92OnSite ?? 'Unknown',
      gasCutoffValve: e.gasCutoffValve ?? 'Unknown',
      depSizeKw: e.depSizeKw ?? '',
      depRegisteredCats: e.depRegisteredCats ?? 'Unknown',
      depCertificateOperate: e.depCertificateOperate ?? 'Unknown',
      tier4Compliant: e.tier4Compliant ?? 'Unknown',
      smokeOrStackTest: e.smokeOrStackTest ?? 'Unknown',
      recordsKept5Years: e.recordsKept5Years ?? false,

      // Operational use
      emergencyOnly: e.emergencyOnly ?? false,
      estimatedAnnualRuntimeHours: e.estimatedAnnualRuntimeHours ?? '',
      fuelFor6hrs: e.fuelFor6hrs ?? 'N/A',
      notes: e.notes ?? '',

      // Post inspection checks
      gensetRunsUnderLoad: e.gensetRunsUnderLoad ?? false,
      voltageFrequencyOk: e.voltageFrequencyOk ?? false,
      exhaustOk: e.exhaustOk ?? false,
      groundingBondingOk: e.groundingBondingOk ?? false,
      controlPanelOk: e.controlPanelOk ?? false,
      safetyDevicesOk: e.safetyDevicesOk ?? false,
      deficienciesDocumented: e.deficienciesDocumented ?? false,
      loadbankDone: e.loadbankDone ?? false,
      atsVerified: e.atsVerified ?? false,
      fuelStoredOver1Yr: e.fuelStoredOver1Yr ?? false,

      // Service / materials
      lastServiceDate: e.lastServiceDate ?? '',
      oilFilterChangeDate: e.oilFilterChangeDate ?? '',
      fuelFilterDate: e.fuelFilterDate ?? '',
      coolantFlushDate: e.coolantFlushDate ?? '',
      batteryReplaceDate: e.batteryReplaceDate ?? '',
      airFilterDate: e.airFilterDate ?? '',

      // Signatures
      technicianSignaturePath: e.technicianSignaturePath ?? '',
      technicianSigDate: e.technicianSigDate,
      customerSignaturePath: e.customerSignaturePath ?? '',
      customerSigDate: e.customerSigDate,
      customerName: e.customerName ?? '',

      // PDF path
      pdfPath: e.pdfPath ?? '',
    );
  }
}
