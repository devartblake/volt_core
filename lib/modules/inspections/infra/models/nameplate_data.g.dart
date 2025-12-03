// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nameplate_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NameplateDataAdapter extends TypeAdapter<NameplateData> {
  @override
  final int typeId = 12;

  @override
  NameplateData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NameplateData(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      generatorMfr: fields[2] as String,
      generatorModel: fields[3] as String,
      generatorSn: fields[4] as String,
      kva: fields[5] as String,
      kw: fields[6] as String,
      volts: fields[7] as String,
      amps: fields[8] as String,
      phase: fields[9] as String,
      cycles: fields[10] as String,
      rpm: fields[11] as String,
      controlMfr: fields[12] as String,
      controlModel: fields[13] as String,
      controlSn: fields[14] as String,
      governorMfr: fields[15] as String,
      governorModel: fields[16] as String,
      governorSn: fields[17] as String,
      regulatorMfr: fields[18] as String,
      regulatorModel: fields[19] as String,
      regulatorSn: fields[20] as String,
      volumeGal: fields[21] as String,
      ullageGal: fields[22] as String,
      ullage90Gal: fields[23] as String,
      tcVolumeGal: fields[24] as String,
      heightGal: fields[25] as String,
      waterGal: fields[26] as String,
      waterInches: fields[27] as String,
      tempF: fields[28] as String,
      time: fields[29] as String,
      comments: fields[30] as String,
      deficiencies: fields[31] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NameplateData obj) {
    writer
      ..writeByte(32)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.generatorMfr)
      ..writeByte(3)
      ..write(obj.generatorModel)
      ..writeByte(4)
      ..write(obj.generatorSn)
      ..writeByte(5)
      ..write(obj.kva)
      ..writeByte(6)
      ..write(obj.kw)
      ..writeByte(7)
      ..write(obj.volts)
      ..writeByte(8)
      ..write(obj.amps)
      ..writeByte(9)
      ..write(obj.phase)
      ..writeByte(10)
      ..write(obj.cycles)
      ..writeByte(11)
      ..write(obj.rpm)
      ..writeByte(12)
      ..write(obj.controlMfr)
      ..writeByte(13)
      ..write(obj.controlModel)
      ..writeByte(14)
      ..write(obj.controlSn)
      ..writeByte(15)
      ..write(obj.governorMfr)
      ..writeByte(16)
      ..write(obj.governorModel)
      ..writeByte(17)
      ..write(obj.governorSn)
      ..writeByte(18)
      ..write(obj.regulatorMfr)
      ..writeByte(19)
      ..write(obj.regulatorModel)
      ..writeByte(20)
      ..write(obj.regulatorSn)
      ..writeByte(21)
      ..write(obj.volumeGal)
      ..writeByte(22)
      ..write(obj.ullageGal)
      ..writeByte(23)
      ..write(obj.ullage90Gal)
      ..writeByte(24)
      ..write(obj.tcVolumeGal)
      ..writeByte(25)
      ..write(obj.heightGal)
      ..writeByte(26)
      ..write(obj.waterGal)
      ..writeByte(27)
      ..write(obj.waterInches)
      ..writeByte(28)
      ..write(obj.tempF)
      ..writeByte(29)
      ..write(obj.time)
      ..writeByte(30)
      ..write(obj.comments)
      ..writeByte(31)
      ..write(obj.deficiencies);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NameplateDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
