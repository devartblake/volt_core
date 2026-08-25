import '../../domain/entities/inspection_entity.dart';
import '../models/inspection.dart' as infra;

/// Temporary mapper between the domain InspectionEntity
/// and the old Hive-backed infra Inspection model used by PdfService.
class InspectionMapper {
  /// Domain → Infra (Hive model) for PDF generation.
  static infra.Inspection fromEntity(InspectionEntity e) {
    return infra.Inspection(
      id: e.id,
      createdAt: e.createdAt,

      // Basic site / meta
      siteCode: e.siteCode,
      siteGrade: e.siteGrade,
      address: e.address,
      addressLine2: e.addressLine2,
      city: e.city,
      state: e.state,
      postalCode: e.postalCode,
      serviceDate: e.serviceDate,
      technicianName: e.technicianName,

      // Generator info
      generatorMake: e.generatorMake,
      generatorModel: e.generatorModel,
      generatorSerial: e.generatorSerial,
      generatorKw: e.generatorKw,
      engineHours: e.engineHours,
      fuelType: e.fuelType,
      voltageRating: e.voltageRating,

      // Location & safety
      locIndoors: e.locIndoors,
      locOutdoors: e.locOutdoors,
      locRoof: e.locRoof,
      locBasement: e.locBasement,
      locOther: e.locOther,
      dedicatedRoom2hr: e.dedicatedRoom2hr,
      separateFromMainService: e.separateFromMainService,
      areaClear: e.areaClear,
      labelsAndEStopVisible: e.labelsAndEStopVisible,
      extinguisherPresent: e.extinguisherPresent,

      // FDNY / DEP
      fuelStoredType: e.fuelStoredType,
      fuelQtyGallons: e.fuelQtyGallons,
      fdnyPermit: e.fdnyPermit,
      c92OnSite: e.c92OnSite,
      gasCutoffValve: e.gasCutoffValve,
      depSizeKw: e.depSizeKw,
      depRegisteredCats: e.depRegisteredCats,
      depCertificateOperate: e.depCertificateOperate,
      tier4Compliant: e.tier4Compliant,
      smokeOrStackTest: e.smokeOrStackTest,
      recordsKept5Years: e.recordsKept5Years,

      // Operational use
      emergencyOnly: e.emergencyOnly,
      estimatedAnnualRuntimeHours: e.estimatedAnnualRuntimeHours,
      fuelFor6hrs: e.fuelFor6hrs,
      notes: e.notes,

      // Post inspection checks
      gensetRunsUnderLoad: e.gensetRunsUnderLoad,
      voltageFrequencyOk: e.voltageFrequencyOk,
      exhaustOk: e.exhaustOk,
      groundingBondingOk: e.groundingBondingOk,
      controlPanelOk: e.controlPanelOk,
      safetyDevicesOk: e.safetyDevicesOk,
      deficienciesDocumented: e.deficienciesDocumented,
      loadbankDone: e.loadbankDone,
      atsVerified: e.atsVerified,
      fuelStoredOver1Yr: e.fuelStoredOver1Yr,

      // Service / materials
      lastServiceDate: e.lastServiceDate,
      oilFilterChangeDate: e.oilFilterChangeDate,
      fuelFilterDate: e.fuelFilterDate,
      coolantFlushDate: e.coolantFlushDate,
      batteryReplaceDate: e.batteryReplaceDate,
      airFilterDate: e.airFilterDate,

      // Signatures
      technicianSignaturePath: e.technicianSignaturePath,
      technicianSigDate: e.technicianSigDate,
      customerSignaturePath: e.customerSignaturePath,
      customerSigDate: e.customerSigDate,
      customerName: e.customerName,

      // PDF path
      pdfPath: e.pdfPath,
      checklistNotes: Map<String, String>.of(e.checklistNotes),
    );
  }
}
