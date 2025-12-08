import 'package:uuid/uuid.dart';

/// Domain entity for a generator inspection.
///
/// This mirrors the key fields from the Hive [Inspection] model,
/// but lives in the domain layer (no Hive imports).
class InspectionEntity {
  final String id;
  final DateTime createdAt;
  final String siteCode;
  final String siteGrade; // "Green" | "Amber" | "Red"
  final String address;
  final DateTime serviceDate;
  final String technicianName;
  final String generatorMake;
  final String generatorModel;
  final String generatorSerial;
  final String generatorKw;
  final String engineHours;
  final String fuelType; // Diesel/Gasoline/None/NaturalGas
  final String voltageRating;

  // Location & Safety (subset, extend as needed)
  final bool locIndoors;
  final bool locOutdoors;
  final bool locRoof;
  final bool locBasement;
  final String locOther;
  final bool dedicatedRoom2hr;
  final bool separateFromMainService;
  final bool areaClear;
  final bool labelsAndEStopVisible;
  final bool extinguisherPresent;

  // FDNY / DEP (subset)
  final String fuelStoredType;
  final String fuelQtyGallons;
  final String fdnyPermit;
  final String c92OnSite;
  final String gasCutoffValve;
  final String depSizeKw;
  final String depRegisteredCats;
  final String depCertificateOperate;
  final String tier4Compliant;
  final String smokeOrStackTest;
  final bool recordsKept5Years;

  // Operational
  final bool emergencyOnly;
  final String estimatedAnnualRuntimeHours;
  final String fuelFor6hrs;
  final String notes;

  // Post-Inspection (subset)
  final bool gensetRunsUnderLoad;
  final bool voltageFrequencyOk;
  final bool exhaustOk;
  final bool groundingBondingOk;
  final bool controlPanelOk;
  final bool safetyDevicesOk;
  final bool deficienciesDocumented;
  final bool loadbankDone;
  final bool atsVerified;
  final bool fuelStoredOver1Yr;

  // Service items (as strings)
  final String lastServiceDate;
  final String oilFilterChangeDate;
  final String fuelFilterDate;
  final String coolantFlushDate;
  final String batteryReplaceDate;
  final String airFilterDate;

  // Signatures & PDF
  final String technicianSignaturePath;
  final DateTime technicianSigDate;
  final String customerSignaturePath;
  final DateTime customerSigDate;
  final String customerName;
  final String pdfPath;

  const InspectionEntity({
    required this.id,
    required this.createdAt,
    this.siteCode = '',
    this.siteGrade = '',
    this.address = '',
    required this.serviceDate,
    this.technicianName = '',
    this.generatorMake = '',
    this.generatorModel = '',
    this.generatorSerial = '',
    this.generatorKw = '',
    this.engineHours = '',
    this.fuelType = '',
    this.voltageRating = '',
    this.locIndoors = false,
    this.locOutdoors = false,
    this.locRoof = false,
    this.locBasement = false,
    this.locOther = '',
    this.dedicatedRoom2hr = false,
    this.separateFromMainService = false,
    this.areaClear = false,
    this.labelsAndEStopVisible = false,
    this.extinguisherPresent = false,
    this.fuelStoredType = '',
    this.fuelQtyGallons = '',
    this.fdnyPermit = 'Unknown',
    this.c92OnSite = 'Unknown',
    this.gasCutoffValve = 'N/A',
    this.depSizeKw = '',
    this.depRegisteredCats = 'Unknown',
    this.depCertificateOperate = 'Unknown',
    this.tier4Compliant = 'Unknown',
    this.smokeOrStackTest = 'Unknown',
    this.recordsKept5Years = false,
    this.emergencyOnly = true,
    this.estimatedAnnualRuntimeHours = '',
    this.fuelFor6hrs = 'N/A',
    this.notes = '',
    this.gensetRunsUnderLoad = false,
    this.voltageFrequencyOk = false,
    this.exhaustOk = false,
    this.groundingBondingOk = false,
    this.controlPanelOk = false,
    this.safetyDevicesOk = false,
    this.deficienciesDocumented = false,
    this.loadbankDone = false,
    this.atsVerified = false,
    this.fuelStoredOver1Yr = false,
    this.lastServiceDate = '',
    this.oilFilterChangeDate = '',
    this.fuelFilterDate = '',
    this.coolantFlushDate = '',
    this.batteryReplaceDate = '',
    this.airFilterDate = '',
    this.technicianSignaturePath = '',
    required this.technicianSigDate,
    this.customerSignaturePath = '',
    required this.customerSigDate,
    this.customerName = '',
    this.pdfPath = '',
  });

  InspectionEntity copyWith({
    String? id,
    DateTime? createdAt,
    String? siteCode,
    String? siteGrade,
    String? address,
    DateTime? serviceDate,
    String? technicianName,
    String? generatorMake,
    String? generatorModel,
    String? generatorSerial,
    String? generatorKw,
    String? engineHours,
    String? fuelType,
    String? voltageRating,
    bool? locIndoors,
    bool? locOutdoors,
    bool? locRoof,
    bool? locBasement,
    String? locOther,
    bool? dedicatedRoom2hr,
    bool? separateFromMainService,
    bool? areaClear,
    bool? labelsAndEStopVisible,
    bool? extinguisherPresent,
    String? fuelStoredType,
    String? fuelQtyGallons,
    String? fdnyPermit,
    String? c92OnSite,
    String? gasCutoffValve,
    String? depSizeKw,
    String? depRegisteredCats,
    String? depCertificateOperate,
    String? tier4Compliant,
    String? smokeOrStackTest,
    bool? recordsKept5Years,
    bool? emergencyOnly,
    String? estimatedAnnualRuntimeHours,
    String? fuelFor6hrs,
    String? notes,
    bool? gensetRunsUnderLoad,
    bool? voltageFrequencyOk,
    bool? exhaustOk,
    bool? groundingBondingOk,
    bool? controlPanelOk,
    bool? safetyDevicesOk,
    bool? deficienciesDocumented,
    bool? loadbankDone,
    bool? atsVerified,
    bool? fuelStoredOver1Yr,
    String? lastServiceDate,
    String? oilFilterChangeDate,
    String? fuelFilterDate,
    String? coolantFlushDate,
    String? batteryReplaceDate,
    String? airFilterDate,
    String? technicianSignaturePath,
    DateTime? technicianSigDate,
    String? customerSignaturePath,
    DateTime? customerSigDate,
    String? customerName,
    String? pdfPath,
  }) {
    return InspectionEntity(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      siteCode: siteCode ?? this.siteCode,
      siteGrade: siteGrade ?? this.siteGrade,
      address: address ?? this.address,
      serviceDate: serviceDate ?? this.serviceDate,
      technicianName: technicianName ?? this.technicianName,
      generatorMake: generatorMake ?? this.generatorMake,
      generatorModel: generatorModel ?? this.generatorModel,
      generatorSerial: generatorSerial ?? this.generatorSerial,
      generatorKw: generatorKw ?? this.generatorKw,
      engineHours: engineHours ?? this.engineHours,
      fuelType: fuelType ?? this.fuelType,
      voltageRating: voltageRating ?? this.voltageRating,
      locIndoors: locIndoors ?? this.locIndoors,
      locOutdoors: locOutdoors ?? this.locOutdoors,
      locRoof: locRoof ?? this.locRoof,
      locBasement: locBasement ?? this.locBasement,
      locOther: locOther ?? this.locOther,
      dedicatedRoom2hr: dedicatedRoom2hr ?? this.dedicatedRoom2hr,
      separateFromMainService:
      separateFromMainService ?? this.separateFromMainService,
      areaClear: areaClear ?? this.areaClear,
      labelsAndEStopVisible:
      labelsAndEStopVisible ?? this.labelsAndEStopVisible,
      extinguisherPresent: extinguisherPresent ?? this.extinguisherPresent,
      fuelStoredType: fuelStoredType ?? this.fuelStoredType,
      fuelQtyGallons: fuelQtyGallons ?? this.fuelQtyGallons,
      fdnyPermit: fdnyPermit ?? this.fdnyPermit,
      c92OnSite: c92OnSite ?? this.c92OnSite,
      gasCutoffValve: gasCutoffValve ?? this.gasCutoffValve,
      depSizeKw: depSizeKw ?? this.depSizeKw,
      depRegisteredCats: depRegisteredCats ?? this.depRegisteredCats,
      depCertificateOperate:
      depCertificateOperate ?? this.depCertificateOperate,
      tier4Compliant: tier4Compliant ?? this.tier4Compliant,
      smokeOrStackTest: smokeOrStackTest ?? this.smokeOrStackTest,
      recordsKept5Years: recordsKept5Years ?? this.recordsKept5Years,
      emergencyOnly: emergencyOnly ?? this.emergencyOnly,
      estimatedAnnualRuntimeHours:
      estimatedAnnualRuntimeHours ?? this.estimatedAnnualRuntimeHours,
      fuelFor6hrs: fuelFor6hrs ?? this.fuelFor6hrs,
      notes: notes ?? this.notes,
      gensetRunsUnderLoad: gensetRunsUnderLoad ?? this.gensetRunsUnderLoad,
      voltageFrequencyOk: voltageFrequencyOk ?? this.voltageFrequencyOk,
      exhaustOk: exhaustOk ?? this.exhaustOk,
      groundingBondingOk: groundingBondingOk ?? this.groundingBondingOk,
      controlPanelOk: controlPanelOk ?? this.controlPanelOk,
      safetyDevicesOk: safetyDevicesOk ?? this.safetyDevicesOk,
      deficienciesDocumented:
      deficienciesDocumented ?? this.deficienciesDocumented,
      loadbankDone: loadbankDone ?? this.loadbankDone,
      atsVerified: atsVerified ?? this.atsVerified,
      fuelStoredOver1Yr: fuelStoredOver1Yr ?? this.fuelStoredOver1Yr,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      oilFilterChangeDate: oilFilterChangeDate ?? this.oilFilterChangeDate,
      fuelFilterDate: fuelFilterDate ?? this.fuelFilterDate,
      coolantFlushDate: coolantFlushDate ?? this.coolantFlushDate,
      batteryReplaceDate: batteryReplaceDate ?? this.batteryReplaceDate,
      airFilterDate: airFilterDate ?? this.airFilterDate,
      technicianSignaturePath:
      technicianSignaturePath ?? this.technicianSignaturePath,
      technicianSigDate: technicianSigDate ?? this.technicianSigDate,
      customerSignaturePath:
      customerSignaturePath ?? this.customerSignaturePath,
      customerSigDate: customerSigDate ?? this.customerSigDate,
      customerName: customerName ?? this.customerName,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }

  /// 🔹 Convenient factory for a new draft inspection
  factory InspectionEntity.newDraft() {
    final now = DateTime.now();
    return InspectionEntity(
      id: const Uuid().v4(),
      createdAt: now,
      siteCode: '',
      siteGrade: '',
      address: '',
      serviceDate: now,
      technicianName: '',
      generatorMake: '',
      generatorModel: '',
      generatorSerial: '',
      generatorKw: '',
      engineHours: '',
      fuelType: '',
      voltageRating: '',
      locIndoors: false,
      locOutdoors: false,
      locRoof: false,
      locBasement: false,
      locOther: '',
      dedicatedRoom2hr: false,
      separateFromMainService: false,
      areaClear: false,
      labelsAndEStopVisible: false,
      extinguisherPresent: false,
      fuelStoredType: '',
      fuelQtyGallons: '',
      fdnyPermit: 'Unknown',
      c92OnSite: 'Unknown',
      gasCutoffValve: 'N/A',
      depSizeKw: '',
      depRegisteredCats: 'Unknown',
      depCertificateOperate: 'Unknown',
      tier4Compliant: 'Unknown',
      smokeOrStackTest: 'Unknown',
      recordsKept5Years: false,
      emergencyOnly: true,
      estimatedAnnualRuntimeHours: '',
      fuelFor6hrs: 'N/A',
      notes: '',
      gensetRunsUnderLoad: false,
      voltageFrequencyOk: false,
      exhaustOk: false,
      groundingBondingOk: false,
      controlPanelOk: false,
      safetyDevicesOk: false,
      deficienciesDocumented: false,
      loadbankDone: false,
      atsVerified: false,
      fuelStoredOver1Yr: false,
      lastServiceDate: '',
      oilFilterChangeDate: '',
      fuelFilterDate: '',
      coolantFlushDate: '',
      batteryReplaceDate: '',
      airFilterDate: '',
      technicianSignaturePath: '',
      technicianSigDate: now,
      customerSignaturePath: '',
      customerSigDate: now,
      customerName: '',
      pdfPath: '',
      // all other fields rely on their default values from the constructor
    );
  }
}
