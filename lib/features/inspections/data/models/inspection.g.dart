// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InspectionAdapter extends TypeAdapter<Inspection> {
  @override
  final int typeId = 10;

  @override
  Inspection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Inspection(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      siteCode: fields[2] as String,
      siteGrade: fields[3] as String,
      address: fields[4] as String,
      serviceDate: fields[5] as DateTime?,
      technicianName: fields[6] as String,
      generatorMake: fields[7] as String,
      generatorModel: fields[8] as String,
      generatorSerial: fields[9] as String,
      generatorKw: fields[10] as String,
      engineHours: fields[11] as String,
      fuelType: fields[12] as String,
      voltageRating: fields[13] as String,
      locIndoors: fields[14] as bool,
      locOutdoors: fields[15] as bool,
      locRoof: fields[16] as bool,
      locBasement: fields[17] as bool,
      locOther: fields[18] as String,
      dedicatedRoom2hr: fields[19] as bool,
      separateFromMainService: fields[20] as bool,
      areaClear: fields[21] as bool,
      labelsAndEStopVisible: fields[22] as bool,
      extinguisherPresent: fields[23] as bool,
      fuelStoredType: fields[24] as String,
      fuelQtyGallons: fields[25] as String,
      fdnyPermit: fields[26] as String,
      c92OnSite: fields[27] as String,
      gasCutoffValve: fields[28] as String,
      depSizeKw: fields[29] as String,
      depRegisteredCats: fields[30] as String,
      depCertificateOperate: fields[31] as String,
      tier4Compliant: fields[32] as String,
      smokeOrStackTest: fields[33] as String,
      recordsKept5Years: fields[34] as bool,
      emergencyOnly: fields[35] as bool,
      estimatedAnnualRuntimeHours: fields[36] as String,
      fuelFor6hrs: fields[37] as String,
      notes: fields[38] as String,
      gensetRunsUnderLoad: fields[39] as bool,
      voltageFrequencyOk: fields[40] as bool,
      exhaustOk: fields[41] as bool,
      groundingBondingOk: fields[42] as bool,
      controlPanelOk: fields[43] as bool,
      safetyDevicesOk: fields[44] as bool,
      deficienciesDocumented: fields[45] as bool,
      loadbankDone: fields[46] as bool,
      atsVerified: fields[47] as bool,
      fuelStoredOver1Yr: fields[48] as bool,
      lastServiceDate: fields[49] as String,
      oilFilterChangeDate: fields[50] as String,
      fuelFilterDate: fields[51] as String,
      coolantFlushDate: fields[52] as String,
      batteryReplaceDate: fields[53] as String,
      airFilterDate: fields[54] as String,
      technicianSignaturePath: fields[55] as String,
      technicianSigDate: fields[56] as DateTime?,
      customerSignaturePath: fields[57] as String,
      customerSigDate: fields[58] as DateTime?,
      customerName: fields[59] as String,
      pdfPath: fields[60] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Inspection obj) {
    writer
      ..writeByte(61)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.siteCode)
      ..writeByte(3)
      ..write(obj.siteGrade)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.serviceDate)
      ..writeByte(6)
      ..write(obj.technicianName)
      ..writeByte(7)
      ..write(obj.generatorMake)
      ..writeByte(8)
      ..write(obj.generatorModel)
      ..writeByte(9)
      ..write(obj.generatorSerial)
      ..writeByte(10)
      ..write(obj.generatorKw)
      ..writeByte(11)
      ..write(obj.engineHours)
      ..writeByte(12)
      ..write(obj.fuelType)
      ..writeByte(13)
      ..write(obj.voltageRating)
      ..writeByte(14)
      ..write(obj.locIndoors)
      ..writeByte(15)
      ..write(obj.locOutdoors)
      ..writeByte(16)
      ..write(obj.locRoof)
      ..writeByte(17)
      ..write(obj.locBasement)
      ..writeByte(18)
      ..write(obj.locOther)
      ..writeByte(19)
      ..write(obj.dedicatedRoom2hr)
      ..writeByte(20)
      ..write(obj.separateFromMainService)
      ..writeByte(21)
      ..write(obj.areaClear)
      ..writeByte(22)
      ..write(obj.labelsAndEStopVisible)
      ..writeByte(23)
      ..write(obj.extinguisherPresent)
      ..writeByte(24)
      ..write(obj.fuelStoredType)
      ..writeByte(25)
      ..write(obj.fuelQtyGallons)
      ..writeByte(26)
      ..write(obj.fdnyPermit)
      ..writeByte(27)
      ..write(obj.c92OnSite)
      ..writeByte(28)
      ..write(obj.gasCutoffValve)
      ..writeByte(29)
      ..write(obj.depSizeKw)
      ..writeByte(30)
      ..write(obj.depRegisteredCats)
      ..writeByte(31)
      ..write(obj.depCertificateOperate)
      ..writeByte(32)
      ..write(obj.tier4Compliant)
      ..writeByte(33)
      ..write(obj.smokeOrStackTest)
      ..writeByte(34)
      ..write(obj.recordsKept5Years)
      ..writeByte(35)
      ..write(obj.emergencyOnly)
      ..writeByte(36)
      ..write(obj.estimatedAnnualRuntimeHours)
      ..writeByte(37)
      ..write(obj.fuelFor6hrs)
      ..writeByte(38)
      ..write(obj.notes)
      ..writeByte(39)
      ..write(obj.gensetRunsUnderLoad)
      ..writeByte(40)
      ..write(obj.voltageFrequencyOk)
      ..writeByte(41)
      ..write(obj.exhaustOk)
      ..writeByte(42)
      ..write(obj.groundingBondingOk)
      ..writeByte(43)
      ..write(obj.controlPanelOk)
      ..writeByte(44)
      ..write(obj.safetyDevicesOk)
      ..writeByte(45)
      ..write(obj.deficienciesDocumented)
      ..writeByte(46)
      ..write(obj.loadbankDone)
      ..writeByte(47)
      ..write(obj.atsVerified)
      ..writeByte(48)
      ..write(obj.fuelStoredOver1Yr)
      ..writeByte(49)
      ..write(obj.lastServiceDate)
      ..writeByte(50)
      ..write(obj.oilFilterChangeDate)
      ..writeByte(51)
      ..write(obj.fuelFilterDate)
      ..writeByte(52)
      ..write(obj.coolantFlushDate)
      ..writeByte(53)
      ..write(obj.batteryReplaceDate)
      ..writeByte(54)
      ..write(obj.airFilterDate)
      ..writeByte(55)
      ..write(obj.technicianSignaturePath)
      ..writeByte(56)
      ..write(obj.technicianSigDate)
      ..writeByte(57)
      ..write(obj.customerSignaturePath)
      ..writeByte(58)
      ..write(obj.customerSigDate)
      ..writeByte(59)
      ..write(obj.customerName)
      ..writeByte(60)
      ..write(obj.pdfPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
