// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceRecordAdapter extends TypeAdapter<MaintenanceRecord> {
  @override
  final int typeId = 40;

  @override
  MaintenanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceRecord(
      id: fields[0] as String,
      inspectionId: fields[1] as String?,
      siteCode: fields[2] as String,
      address: fields[3] as String,
      dateOfService: fields[4] as DateTime?,
      technicianName: fields[5] as String,
      generatorMake: fields[6] as String,
      generatorModel: fields[7] as String,
      generatorSerial: fields[8] as String,
      generatorKw: fields[9] as String,
      engineHours: fields[10] as String,
      fuelType: fields[11] as String,
      lastFuelDeliveryDate: fields[12] as String,
      voltageRating: fields[13] as String,
      generatorLocation: fields[14] as String,
      generatorLocationOther: fields[15] as String,
      enclosureDamaged: fields[16] as bool,
      enclosureIntact: fields[17] as bool,
      noEnclosure: fields[18] as bool,
      visibleDamageOrLeaks: fields[19] as bool,
      areaClearOfHazards: fields[20] as bool,
      warningLabelsVisible: fields[21] as bool,
      fireExtinguisherPresent: fields[22] as bool,
      batteryNeedsReplace: fields[23] as bool,
      batteryRecentlyReplaced: fields[24] as bool,
      batteryMfgDate: fields[25] as String,
      batteryPartNo: fields[26] as String,
      batteryType: fields[27] as String,
      airFilterNeedsReplace: fields[28] as bool,
      airFilterRecentlyReplaced: fields[29] as bool,
      airFilterLastReplacedDate: fields[30] as String,
      airFilterPartNo: fields[31] as String,
      coolantLevel: fields[32] as String,
      coolantColor: fields[33] as String,
      coolantHosesCompromised: fields[34] as bool,
      coolantHosesRecommendChange: fields[35] as bool,
      coolantHosesInfo: fields[36] as String,
      fuelHosesCompromised: fields[37] as bool,
      fuelHosesRecommendChange: fields[38] as bool,
      fuelHosesInfo: fields[39] as String,
      airIntakeHosesCompromised: fields[40] as bool,
      airIntakeHosesRecommendChange: fields[41] as bool,
      airIntakeHosesInfo: fields[42] as String,
      oilHosesCompromised: fields[43] as bool,
      oilHosesRecommendChange: fields[44] as bool,
      oilHosesInfo: fields[45] as String,
      additionalHosesCompromised: fields[46] as bool,
      additionalHosesRecommendChange: fields[47] as bool,
      additionalHosesInfo: fields[48] as String,
      canLube: fields[49] as bool,
      canLubePartNo: fields[50] as String,
      canFuel: fields[51] as bool,
      canFuelPartNo: fields[52] as String,
      canWaterSep: fields[53] as bool,
      canWaterSepPartNo: fields[54] as String,
      canOil: fields[55] as bool,
      canOilPartNo: fields[56] as String,
      canOther1: fields[57] as bool,
      canOther1Label: fields[58] as String,
      canOther1PartNo: fields[59] as String,
      canOther2: fields[60] as bool,
      canOther2Label: fields[61] as String,
      canOther2PartNo: fields[62] as String,
      oilFilterChanged: fields[63] as bool,
      oilFilterNotes: fields[64] as String,
      fuelFilterReplaced: fields[65] as bool,
      fuelFilterNotes: fields[66] as String,
      coolantFlushed: fields[67] as bool,
      coolantNotes: fields[68] as String,
      batteryReplaced: fields[69] as bool,
      batteryNotes: fields[70] as String,
      airFilterReplaced: fields[71] as bool,
      airFilterNotes: fields[72] as String,
      beltsHosesReplaced: fields[73] as bool,
      beltsHosesNotes: fields[74] as String,
      blockHeaterTested: fields[75] as bool,
      blockHeaterNotes: fields[76] as String,
      racorServiced: fields[77] as bool,
      racorNotes: fields[78] as String,
      atsControllerInspected: fields[79] as bool,
      atsControllerNotes: fields[80] as String,
      cdvrProgrammed: fields[81] as bool,
      cdvrNotes: fields[82] as String,
      undervoltageRepaired: fields[83] as bool,
      undervoltageNotes: fields[84] as String,
      hazmatRemoved: fields[85] as bool,
      hazmatNotes: fields[86] as String,
      serviceObservations: fields[87] as String,
      postVerifyRunsUnderLoad: fields[88] as bool,
      postCheckVoltFreq: fields[89] as bool,
      postInspectExhaust: fields[90] as bool,
      postVerifyGrounding: fields[91] as bool,
      postCheckControlPanel: fields[92] as bool,
      postEnsureSafetyDevices: fields[93] as bool,
      postDocumentDeficiencies: fields[94] as bool,
      postLoadbankTest: fields[95] as bool,
      postAtsFunctionality: fields[96] as bool,
      fuelStoredLong: fields[97] as bool,
      partsOilTypeQty: fields[98] as String,
      partsCoolantTypeQty: fields[99] as String,
      partsFilterTypes: fields[100] as String,
      partsBatteryTypeDate: fields[101] as String,
      partsBeltsHosesReplaced: fields[102] as String,
      partsBlockHeaterWattage: fields[103] as String,
      partsCdvrSerial: fields[104] as String,
      technicianSignatureName: fields[105] as String,
      technicianSignatureDate: fields[106] as DateTime?,
      customerSignatureName: fields[107] as String,
      customerSignatureDate: fields[108] as DateTime?,
      generalNotes: fields[111] as String?,
      completed: fields[112] as bool,
      requiresFollowUp: fields[113] as bool,
      followUpNotes: fields[114] as String?,
      createdAt: fields[109] as DateTime?,
      updatedAt: fields[110] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceRecord obj) {
    writer
      ..writeByte(115)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.siteCode)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.dateOfService)
      ..writeByte(5)
      ..write(obj.technicianName)
      ..writeByte(6)
      ..write(obj.generatorMake)
      ..writeByte(7)
      ..write(obj.generatorModel)
      ..writeByte(8)
      ..write(obj.generatorSerial)
      ..writeByte(9)
      ..write(obj.generatorKw)
      ..writeByte(10)
      ..write(obj.engineHours)
      ..writeByte(11)
      ..write(obj.fuelType)
      ..writeByte(12)
      ..write(obj.lastFuelDeliveryDate)
      ..writeByte(13)
      ..write(obj.voltageRating)
      ..writeByte(14)
      ..write(obj.generatorLocation)
      ..writeByte(15)
      ..write(obj.generatorLocationOther)
      ..writeByte(16)
      ..write(obj.enclosureDamaged)
      ..writeByte(17)
      ..write(obj.enclosureIntact)
      ..writeByte(18)
      ..write(obj.noEnclosure)
      ..writeByte(19)
      ..write(obj.visibleDamageOrLeaks)
      ..writeByte(20)
      ..write(obj.areaClearOfHazards)
      ..writeByte(21)
      ..write(obj.warningLabelsVisible)
      ..writeByte(22)
      ..write(obj.fireExtinguisherPresent)
      ..writeByte(23)
      ..write(obj.batteryNeedsReplace)
      ..writeByte(24)
      ..write(obj.batteryRecentlyReplaced)
      ..writeByte(25)
      ..write(obj.batteryMfgDate)
      ..writeByte(26)
      ..write(obj.batteryPartNo)
      ..writeByte(27)
      ..write(obj.batteryType)
      ..writeByte(28)
      ..write(obj.airFilterNeedsReplace)
      ..writeByte(29)
      ..write(obj.airFilterRecentlyReplaced)
      ..writeByte(30)
      ..write(obj.airFilterLastReplacedDate)
      ..writeByte(31)
      ..write(obj.airFilterPartNo)
      ..writeByte(32)
      ..write(obj.coolantLevel)
      ..writeByte(33)
      ..write(obj.coolantColor)
      ..writeByte(34)
      ..write(obj.coolantHosesCompromised)
      ..writeByte(35)
      ..write(obj.coolantHosesRecommendChange)
      ..writeByte(36)
      ..write(obj.coolantHosesInfo)
      ..writeByte(37)
      ..write(obj.fuelHosesCompromised)
      ..writeByte(38)
      ..write(obj.fuelHosesRecommendChange)
      ..writeByte(39)
      ..write(obj.fuelHosesInfo)
      ..writeByte(40)
      ..write(obj.airIntakeHosesCompromised)
      ..writeByte(41)
      ..write(obj.airIntakeHosesRecommendChange)
      ..writeByte(42)
      ..write(obj.airIntakeHosesInfo)
      ..writeByte(43)
      ..write(obj.oilHosesCompromised)
      ..writeByte(44)
      ..write(obj.oilHosesRecommendChange)
      ..writeByte(45)
      ..write(obj.oilHosesInfo)
      ..writeByte(46)
      ..write(obj.additionalHosesCompromised)
      ..writeByte(47)
      ..write(obj.additionalHosesRecommendChange)
      ..writeByte(48)
      ..write(obj.additionalHosesInfo)
      ..writeByte(49)
      ..write(obj.canLube)
      ..writeByte(50)
      ..write(obj.canLubePartNo)
      ..writeByte(51)
      ..write(obj.canFuel)
      ..writeByte(52)
      ..write(obj.canFuelPartNo)
      ..writeByte(53)
      ..write(obj.canWaterSep)
      ..writeByte(54)
      ..write(obj.canWaterSepPartNo)
      ..writeByte(55)
      ..write(obj.canOil)
      ..writeByte(56)
      ..write(obj.canOilPartNo)
      ..writeByte(57)
      ..write(obj.canOther1)
      ..writeByte(58)
      ..write(obj.canOther1Label)
      ..writeByte(59)
      ..write(obj.canOther1PartNo)
      ..writeByte(60)
      ..write(obj.canOther2)
      ..writeByte(61)
      ..write(obj.canOther2Label)
      ..writeByte(62)
      ..write(obj.canOther2PartNo)
      ..writeByte(63)
      ..write(obj.oilFilterChanged)
      ..writeByte(64)
      ..write(obj.oilFilterNotes)
      ..writeByte(65)
      ..write(obj.fuelFilterReplaced)
      ..writeByte(66)
      ..write(obj.fuelFilterNotes)
      ..writeByte(67)
      ..write(obj.coolantFlushed)
      ..writeByte(68)
      ..write(obj.coolantNotes)
      ..writeByte(69)
      ..write(obj.batteryReplaced)
      ..writeByte(70)
      ..write(obj.batteryNotes)
      ..writeByte(71)
      ..write(obj.airFilterReplaced)
      ..writeByte(72)
      ..write(obj.airFilterNotes)
      ..writeByte(73)
      ..write(obj.beltsHosesReplaced)
      ..writeByte(74)
      ..write(obj.beltsHosesNotes)
      ..writeByte(75)
      ..write(obj.blockHeaterTested)
      ..writeByte(76)
      ..write(obj.blockHeaterNotes)
      ..writeByte(77)
      ..write(obj.racorServiced)
      ..writeByte(78)
      ..write(obj.racorNotes)
      ..writeByte(79)
      ..write(obj.atsControllerInspected)
      ..writeByte(80)
      ..write(obj.atsControllerNotes)
      ..writeByte(81)
      ..write(obj.cdvrProgrammed)
      ..writeByte(82)
      ..write(obj.cdvrNotes)
      ..writeByte(83)
      ..write(obj.undervoltageRepaired)
      ..writeByte(84)
      ..write(obj.undervoltageNotes)
      ..writeByte(85)
      ..write(obj.hazmatRemoved)
      ..writeByte(86)
      ..write(obj.hazmatNotes)
      ..writeByte(87)
      ..write(obj.serviceObservations)
      ..writeByte(88)
      ..write(obj.postVerifyRunsUnderLoad)
      ..writeByte(89)
      ..write(obj.postCheckVoltFreq)
      ..writeByte(90)
      ..write(obj.postInspectExhaust)
      ..writeByte(91)
      ..write(obj.postVerifyGrounding)
      ..writeByte(92)
      ..write(obj.postCheckControlPanel)
      ..writeByte(93)
      ..write(obj.postEnsureSafetyDevices)
      ..writeByte(94)
      ..write(obj.postDocumentDeficiencies)
      ..writeByte(95)
      ..write(obj.postLoadbankTest)
      ..writeByte(96)
      ..write(obj.postAtsFunctionality)
      ..writeByte(97)
      ..write(obj.fuelStoredLong)
      ..writeByte(98)
      ..write(obj.partsOilTypeQty)
      ..writeByte(99)
      ..write(obj.partsCoolantTypeQty)
      ..writeByte(100)
      ..write(obj.partsFilterTypes)
      ..writeByte(101)
      ..write(obj.partsBatteryTypeDate)
      ..writeByte(102)
      ..write(obj.partsBeltsHosesReplaced)
      ..writeByte(103)
      ..write(obj.partsBlockHeaterWattage)
      ..writeByte(104)
      ..write(obj.partsCdvrSerial)
      ..writeByte(105)
      ..write(obj.technicianSignatureName)
      ..writeByte(106)
      ..write(obj.technicianSignatureDate)
      ..writeByte(107)
      ..write(obj.customerSignatureName)
      ..writeByte(108)
      ..write(obj.customerSignatureDate)
      ..writeByte(109)
      ..write(obj.createdAt)
      ..writeByte(110)
      ..write(obj.updatedAt)
      ..writeByte(111)
      ..write(obj.generalNotes)
      ..writeByte(112)
      ..write(obj.completed)
      ..writeByte(113)
      ..write(obj.requiresFollowUp)
      ..writeByte(114)
      ..write(obj.followUpNotes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
