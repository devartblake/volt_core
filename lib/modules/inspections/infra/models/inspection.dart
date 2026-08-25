import 'package:hive/hive.dart';
import '../../domain/entities/inspection_entity.dart';

part 'inspection.g.dart';

@HiveType(typeId: 10)
class Inspection extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) DateTime createdAt;
  @HiveField(2) String siteCode;
  @HiveField(3) String siteGrade; // "Green" | "Amber" | "Red"
  @HiveField(4) String address;
  @HiveField(5) DateTime serviceDate;
  @HiveField(6) String technicianName;
  @HiveField(7) String generatorMake;
  @HiveField(8) String generatorModel;
  @HiveField(9) String generatorSerial;
  @HiveField(10) String generatorKw;
  @HiveField(11) String engineHours;
  @HiveField(12) String fuelType; // Diesel/Gasoline/None/NaturalGas
  @HiveField(13) String voltageRating;

  // Location & Safety (booleans as ints for Hive compactness)
  @HiveField(14) bool locIndoors;
  @HiveField(15) bool locOutdoors;
  @HiveField(16) bool locRoof;
  @HiveField(17) bool locBasement;
  @HiveField(18) String locOther;
  @HiveField(19) bool dedicatedRoom2hr;
  @HiveField(20) bool separateFromMainService;
  @HiveField(21) bool areaClear;
  @HiveField(22) bool labelsAndEStopVisible;
  @HiveField(23) bool extinguisherPresent;

  // FDNY / DEP
  @HiveField(24) String fuelStoredType; // Diesel/Gasoline/None
  @HiveField(25) String fuelQtyGallons;
  @HiveField(26) String fdnyPermit; // Yes/No/Unknown
  @HiveField(27) String c92OnSite;  // Yes/No/Unknown
  @HiveField(28) String gasCutoffValve; // Yes/No/NA
  @HiveField(29) String depSizeKw;
  @HiveField(30) String depRegisteredCats; // Yes/No/Unknown
  @HiveField(31) String depCertificateOperate; // Yes/No/Unknown
  @HiveField(32) String tier4Compliant; // Yes/No/Unknown
  @HiveField(33) String smokeOrStackTest; // Yes/No/Unknown
  @HiveField(34) bool recordsKept5Years;

  // Operational
  @HiveField(35) bool emergencyOnly;
  @HiveField(36) String estimatedAnnualRuntimeHours;
  @HiveField(37) String fuelFor6hrs; // Yes/No/NA
  @HiveField(38) String notes;

  // Post-Inspection (a subset shown; add all you need)
  @HiveField(39) bool gensetRunsUnderLoad;
  @HiveField(40) bool voltageFrequencyOk;
  @HiveField(41) bool exhaustOk;
  @HiveField(42) bool groundingBondingOk;
  @HiveField(43) bool controlPanelOk;
  @HiveField(44) bool safetyDevicesOk;
  @HiveField(45) bool deficienciesDocumented;
  @HiveField(46) bool loadbankDone;
  @HiveField(47) bool atsVerified;
  @HiveField(48) bool fuelStoredOver1Yr;

  // Service items
  @HiveField(49) String lastServiceDate;
  @HiveField(50) String oilFilterChangeDate;
  @HiveField(51) String fuelFilterDate;
  @HiveField(52) String coolantFlushDate;
  @HiveField(53) String batteryReplaceDate;
  @HiveField(54) String airFilterDate;

  // Signatures (store PNG bytes paths for PDF, plus typed names/dates)
  @HiveField(55) String technicianSignaturePath;
  @HiveField(56) DateTime technicianSigDate;
  @HiveField(57) String customerSignaturePath;
  @HiveField(58) DateTime customerSigDate;
  @HiveField(59) String customerName;

  // Generated PDF path
  @HiveField(60) String pdfPath;

  // Address parts. Field 4 (`address`) stays the street line; records written
  // before this split hold their whole one-line address there and simply leave
  // these empty.
  //
  // NOTE: inspection.g.dart is checked in without build_runner in the
  // pubspec, so it is maintained by hand. Fields 61+ are read with null-safe
  // casts because rows written before they existed have no entry for them —
  // regenerating this adapter would emit bare `as String` casts and start
  // throwing on every pre-existing inspection.
  @HiveField(61) String addressLine2;
  @HiveField(62) String city;
  @HiveField(63) String state;
  @HiveField(64) String postalCode;

  /// Per-checklist-item conclusions, keyed by InspectionChecklistItem.key.
  @HiveField(65) Map<String, String> checklistNotes;

  Inspection({
    required this.id,
    required this.createdAt,
    this.siteCode = '',
    this.siteGrade = '',
    this.address = '',
    DateTime? serviceDate,
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
    DateTime? technicianSigDate,
    this.customerSignaturePath = '',
    DateTime? customerSigDate,
    this.customerName = '',
    this.pdfPath = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    Map<String, String>? checklistNotes,
  })  : checklistNotes = checklistNotes ?? <String, String>{},
        serviceDate = serviceDate ?? DateTime.now(),
        technicianSigDate = technicianSigDate ?? DateTime.now(),
        customerSigDate = customerSigDate ?? DateTime.now();
}

// ====== DOMAIN MAPPER ======

extension InspectionHiveMapper on Inspection {
  /// The whole address on one line, for the printed report.
  ///
  /// Field 4 holds only the street line since the address was split into
  /// parts; records written before that hold their entire address there and
  /// compose back to exactly the same string.
  String get formattedAddress => composeAddress(
        line1: address,
        line2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
      );

  InspectionEntity toEntity() {
    return InspectionEntity(
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(), // Hive model has no updatedAt field; use current time as fallback
      siteCode: siteCode,
      siteGrade: siteGrade,
      address: address,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      serviceDate: serviceDate,
      technicianName: technicianName,
      generatorMake: generatorMake,
      generatorModel: generatorModel,
      generatorSerial: generatorSerial,
      generatorKw: generatorKw,
      engineHours: engineHours,
      fuelType: fuelType,
      voltageRating: voltageRating,
      locIndoors: locIndoors,
      locOutdoors: locOutdoors,
      locRoof: locRoof,
      locBasement: locBasement,
      locOther: locOther,
      dedicatedRoom2hr: dedicatedRoom2hr,
      separateFromMainService: separateFromMainService,
      areaClear: areaClear,
      labelsAndEStopVisible: labelsAndEStopVisible,
      extinguisherPresent: extinguisherPresent,
      fuelStoredType: fuelStoredType,
      fuelQtyGallons: fuelQtyGallons,
      fdnyPermit: fdnyPermit,
      c92OnSite: c92OnSite,
      gasCutoffValve: gasCutoffValve,
      depSizeKw: depSizeKw,
      depRegisteredCats: depRegisteredCats,
      depCertificateOperate: depCertificateOperate,
      tier4Compliant: tier4Compliant,
      smokeOrStackTest: smokeOrStackTest,
      recordsKept5Years: recordsKept5Years,
      emergencyOnly: emergencyOnly,
      estimatedAnnualRuntimeHours: estimatedAnnualRuntimeHours,
      fuelFor6hrs: fuelFor6hrs,
      notes: notes,
      gensetRunsUnderLoad: gensetRunsUnderLoad,
      voltageFrequencyOk: voltageFrequencyOk,
      exhaustOk: exhaustOk,
      groundingBondingOk: groundingBondingOk,
      controlPanelOk: controlPanelOk,
      safetyDevicesOk: safetyDevicesOk,
      deficienciesDocumented: deficienciesDocumented,
      loadbankDone: loadbankDone,
      atsVerified: atsVerified,
      fuelStoredOver1Yr: fuelStoredOver1Yr,
      lastServiceDate: lastServiceDate,
      oilFilterChangeDate: oilFilterChangeDate,
      fuelFilterDate: fuelFilterDate,
      coolantFlushDate: coolantFlushDate,
      batteryReplaceDate: batteryReplaceDate,
      airFilterDate: airFilterDate,
      technicianSignaturePath: technicianSignaturePath,
      technicianSigDate: technicianSigDate,
      customerSignaturePath: customerSignaturePath,
      customerSigDate: customerSigDate,
      customerName: customerName,
      pdfPath: pdfPath,
      checklistNotes: Map<String, String>.of(checklistNotes),
    );
  }
}

/// Helper to create a Hive [Inspection] from a domain [InspectionEntity].
Inspection inspectionFromEntity(InspectionEntity e) {
  return Inspection(
    id: e.id,
    createdAt: e.createdAt,
    siteCode: e.siteCode,
    siteGrade: e.siteGrade,
    address: e.address,
    addressLine2: e.addressLine2,
    city: e.city,
    state: e.state,
    postalCode: e.postalCode,
    serviceDate: e.serviceDate,
    technicianName: e.technicianName,
    generatorMake: e.generatorMake,
    generatorModel: e.generatorModel,
    generatorSerial: e.generatorSerial,
    generatorKw: e.generatorKw,
    engineHours: e.engineHours,
    fuelType: e.fuelType,
    voltageRating: e.voltageRating,
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
    emergencyOnly: e.emergencyOnly,
    estimatedAnnualRuntimeHours: e.estimatedAnnualRuntimeHours,
    fuelFor6hrs: e.fuelFor6hrs,
    notes: e.notes,
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
    lastServiceDate: e.lastServiceDate,
    oilFilterChangeDate: e.oilFilterChangeDate,
    fuelFilterDate: e.fuelFilterDate,
    coolantFlushDate: e.coolantFlushDate,
    batteryReplaceDate: e.batteryReplaceDate,
    airFilterDate: e.airFilterDate,
    technicianSignaturePath: e.technicianSignaturePath,
    technicianSigDate: e.technicianSigDate,
    customerSignaturePath: e.customerSignaturePath,
    customerSigDate: e.customerSigDate,
    customerName: e.customerName,
    pdfPath: e.pdfPath,
    checklistNotes: Map<String, String>.of(e.checklistNotes),
  );
}
