import 'package:hive/hive.dart';

part 'maintenance_record.g.dart';

@HiveType(typeId: 40) // <-- pick a free typeId
class MaintenanceRecord extends HiveObject {
  @HiveField(0)
  String id;

  // Link to an existing inspection if you want (optional)
  @HiveField(1)
  String? inspectionId;

  // Site & generator info (same as maintenance PDF)
  @HiveField(2)
  String siteCode;
  @HiveField(3)
  String address;
  @HiveField(4)
  DateTime? dateOfService;
  @HiveField(5)
  String technicianName;
  @HiveField(6)
  String generatorMake;
  @HiveField(7)
  String generatorModel;
  @HiveField(8)
  String generatorSerial;
  @HiveField(9)
  String generatorKw;
  @HiveField(10)
  String engineHours;
  @HiveField(11)
  String fuelType;
  @HiveField(12)
  String lastFuelDeliveryDate;
  @HiveField(13)
  String voltageRating;

  // Pre-inspection / Initial Walkthrough
  @HiveField(14)
  String generatorLocation; // Indoors / Outdoors / Roof / Basement / Other
  @HiveField(15)
  String generatorLocationOther;

  @HiveField(16)
  bool enclosureDamaged;
  @HiveField(17)
  bool enclosureIntact;
  @HiveField(18)
  bool noEnclosure;

  @HiveField(19)
  bool visibleDamageOrLeaks;
  @HiveField(20)
  bool areaClearOfHazards;
  @HiveField(21)
  bool warningLabelsVisible;
  @HiveField(22)
  bool fireExtinguisherPresent;

  // General Maintenance – Battery
  @HiveField(23)
  bool batteryNeedsReplace;
  @HiveField(24)
  bool batteryRecentlyReplaced;
  @HiveField(25)
  String batteryMfgDate;
  @HiveField(26)
  String batteryPartNo;
  @HiveField(27)
  String batteryType; // Lead Acid / NiCad

  // Air filter
  @HiveField(28)
  bool airFilterNeedsReplace;
  @HiveField(29)
  bool airFilterRecentlyReplaced;
  @HiveField(30)
  String airFilterLastReplacedDate;
  @HiveField(31)
  String airFilterPartNo;

  // Coolant
  @HiveField(32)
  String coolantLevel; // Full / 50% / Low
  @HiveField(33)
  String coolantColor; // Green / Orange / Blue / Unknown

  // Hoses (each: compromised/intact + recommend change + note)
  @HiveField(34)
  bool coolantHosesCompromised;
  @HiveField(35)
  bool coolantHosesRecommendChange;
  @HiveField(36)
  String coolantHosesInfo;

  @HiveField(37)
  bool fuelHosesCompromised;
  @HiveField(38)
  bool fuelHosesRecommendChange;
  @HiveField(39)
  String fuelHosesInfo;

  @HiveField(40)
  bool airIntakeHosesCompromised;
  @HiveField(41)
  bool airIntakeHosesRecommendChange;
  @HiveField(42)
  String airIntakeHosesInfo;

  @HiveField(43)
  bool oilHosesCompromised;
  @HiveField(44)
  bool oilHosesRecommendChange;
  @HiveField(45)
  String oilHosesInfo;

  @HiveField(46)
  bool additionalHosesCompromised;
  @HiveField(47)
  bool additionalHosesRecommendChange;
  @HiveField(48)
  String additionalHosesInfo;

  // Cannister Need (filters & part numbers)
  @HiveField(49)
  bool canLube;
  @HiveField(50)
  String canLubePartNo;
  @HiveField(51)
  bool canFuel;
  @HiveField(52)
  String canFuelPartNo;
  @HiveField(53)
  bool canWaterSep;
  @HiveField(54)
  String canWaterSepPartNo;
  @HiveField(55)
  bool canOil;
  @HiveField(56)
  String canOilPartNo;
  @HiveField(57)
  bool canOther1;
  @HiveField(58)
  String canOther1Label;
  @HiveField(59)
  String canOther1PartNo;
  @HiveField(60)
  bool canOther2;
  @HiveField(61)
  String canOther2Label;
  @HiveField(62)
  String canOther2PartNo;

  // Maintenance actions performed (Yes/No + notes)
  @HiveField(63)
  bool oilFilterChanged;
  @HiveField(64)
  String oilFilterNotes;

  @HiveField(65)
  bool fuelFilterReplaced;
  @HiveField(66)
  String fuelFilterNotes;

  @HiveField(67)
  bool coolantFlushed;
  @HiveField(68)
  String coolantNotes;

  @HiveField(69)
  bool batteryReplaced;
  @HiveField(70)
  String batteryNotes;

  @HiveField(71)
  bool airFilterReplaced;
  @HiveField(72)
  String airFilterNotes;

  @HiveField(73)
  bool beltsHosesReplaced;
  @HiveField(74)
  String beltsHosesNotes;

  @HiveField(75)
  bool blockHeaterTested;
  @HiveField(76)
  String blockHeaterNotes;

  @HiveField(77)
  bool racorServiced;
  @HiveField(78)
  String racorNotes;

  @HiveField(79)
  bool atsControllerInspected;
  @HiveField(80)
  String atsControllerNotes;

  @HiveField(81)
  bool cdvrProgrammed;
  @HiveField(82)
  String cdvrNotes;

  @HiveField(83)
  bool undervoltageRepaired;
  @HiveField(84)
  String undervoltageNotes;

  @HiveField(85)
  bool hazmatRemoved;
  @HiveField(86)
  String hazmatNotes;

  @HiveField(87)
  String serviceObservations;

  // Post service checklist (Yes/No)
  @HiveField(88)
  bool postVerifyRunsUnderLoad;
  @HiveField(89)
  bool postCheckVoltFreq;
  @HiveField(90)
  bool postInspectExhaust;
  @HiveField(91)
  bool postVerifyGrounding;
  @HiveField(92)
  bool postCheckControlPanel;
  @HiveField(93)
  bool postEnsureSafetyDevices;
  @HiveField(94)
  bool postDocumentDeficiencies;
  @HiveField(95)
  bool postLoadbankTest;
  @HiveField(96)
  bool postAtsFunctionality;
  @HiveField(97)
  bool fuelStoredLong;

  // Parts & Materials Used
  @HiveField(98)
  String partsOilTypeQty;
  @HiveField(99)
  String partsCoolantTypeQty;
  @HiveField(100)
  String partsFilterTypes;
  @HiveField(101)
  String partsBatteryTypeDate;
  @HiveField(102)
  String partsBeltsHosesReplaced;
  @HiveField(103)
  String partsBlockHeaterWattage;
  @HiveField(104)
  String partsCdvrSerial;

  // Signatures & metadata
  @HiveField(105)
  String technicianSignatureName;
  @HiveField(106)
  DateTime? technicianSignatureDate;
  @HiveField(107)
  String customerSignatureName;
  @HiveField(108)
  DateTime? customerSignatureDate;

  @HiveField(109)
  DateTime createdAt;
  @HiveField(110)
  DateTime updatedAt;

  @HiveField(111)
  String? generalNotes;

  @HiveField(112)
  bool completed;

  @HiveField(113)
  bool requiresFollowUp;

  @HiveField(114)
  String? followUpNotes;

  MaintenanceRecord({
    required this.id,
    this.inspectionId,
    this.siteCode = '',
    this.address = '',
    this.dateOfService,
    this.technicianName = '',
    this.generatorMake = '',
    this.generatorModel = '',
    this.generatorSerial = '',
    this.generatorKw = '',
    this.engineHours = '',
    this.fuelType = '',
    this.lastFuelDeliveryDate = '',
    this.voltageRating = '',
    this.generatorLocation = '',
    this.generatorLocationOther = '',
    this.enclosureDamaged = false,
    this.enclosureIntact = false,
    this.noEnclosure = false,
    this.visibleDamageOrLeaks = false,
    this.areaClearOfHazards = false,
    this.warningLabelsVisible = false,
    this.fireExtinguisherPresent = false,
    this.batteryNeedsReplace = false,
    this.batteryRecentlyReplaced = false,
    this.batteryMfgDate = '',
    this.batteryPartNo = '',
    this.batteryType = '',
    this.airFilterNeedsReplace = false,
    this.airFilterRecentlyReplaced = false,
    this.airFilterLastReplacedDate = '',
    this.airFilterPartNo = '',
    this.coolantLevel = '',
    this.coolantColor = '',
    this.coolantHosesCompromised = false,
    this.coolantHosesRecommendChange = false,
    this.coolantHosesInfo = '',
    this.fuelHosesCompromised = false,
    this.fuelHosesRecommendChange = false,
    this.fuelHosesInfo = '',
    this.airIntakeHosesCompromised = false,
    this.airIntakeHosesRecommendChange = false,
    this.airIntakeHosesInfo = '',
    this.oilHosesCompromised = false,
    this.oilHosesRecommendChange = false,
    this.oilHosesInfo = '',
    this.additionalHosesCompromised = false,
    this.additionalHosesRecommendChange = false,
    this.additionalHosesInfo = '',
    this.canLube = false,
    this.canLubePartNo = '',
    this.canFuel = false,
    this.canFuelPartNo = '',
    this.canWaterSep = false,
    this.canWaterSepPartNo = '',
    this.canOil = false,
    this.canOilPartNo = '',
    this.canOther1 = false,
    this.canOther1Label = '',
    this.canOther1PartNo = '',
    this.canOther2 = false,
    this.canOther2Label = '',
    this.canOther2PartNo = '',
    this.oilFilterChanged = false,
    this.oilFilterNotes = '',
    this.fuelFilterReplaced = false,
    this.fuelFilterNotes = '',
    this.coolantFlushed = false,
    this.coolantNotes = '',
    this.batteryReplaced = false,
    this.batteryNotes = '',
    this.airFilterReplaced = false,
    this.airFilterNotes = '',
    this.beltsHosesReplaced = false,
    this.beltsHosesNotes = '',
    this.blockHeaterTested = false,
    this.blockHeaterNotes = '',
    this.racorServiced = false,
    this.racorNotes = '',
    this.atsControllerInspected = false,
    this.atsControllerNotes = '',
    this.cdvrProgrammed = false,
    this.cdvrNotes = '',
    this.undervoltageRepaired = false,
    this.undervoltageNotes = '',
    this.hazmatRemoved = false,
    this.hazmatNotes = '',
    this.serviceObservations = '',
    this.postVerifyRunsUnderLoad = false,
    this.postCheckVoltFreq = false,
    this.postInspectExhaust = false,
    this.postVerifyGrounding = false,
    this.postCheckControlPanel = false,
    this.postEnsureSafetyDevices = false,
    this.postDocumentDeficiencies = false,
    this.postLoadbankTest = false,
    this.postAtsFunctionality = false,
    this.fuelStoredLong = false,
    this.partsOilTypeQty = '',
    this.partsCoolantTypeQty = '',
    this.partsFilterTypes = '',
    this.partsBatteryTypeDate = '',
    this.partsBeltsHosesReplaced = '',
    this.partsBlockHeaterWattage = '',
    this.partsCdvrSerial = '',
    this.technicianSignatureName = '',
    this.technicianSignatureDate,
    this.customerSignatureName = '',
    this.customerSignatureDate,
    this.generalNotes = '',
    this.completed = false,
    this.requiresFollowUp = false,
    this.followUpNotes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
