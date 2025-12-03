// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_interval_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestIntervalRecordAdapter extends TypeAdapter<TestIntervalRecord> {
  @override
  final int typeId = 13;

  @override
  TestIntervalRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestIntervalRecord(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      index: fields[2] as int,
      realtimeKwTarget: fields[3] as String,
      engineRpm: fields[4] as String,
      frequencyHz: fields[5] as String,
      engineWaterF: fields[6] as String,
      radiatorWaterF: fields[7] as String,
      engineOilTempF: fields[8] as String,
      engineOilPsi: fields[9] as String,
      panelVolt: fields[10] as String,
      measuredVolt: fields[11] as String,
      panelAmp: fields[12] as String,
      measuredAmp: fields[13] as String,
      panelKw: fields[14] as String,
      measuredKw: fields[15] as String,
      batteryVolt: fields[16] as String,
      fuelPressure: fields[17] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TestIntervalRecord obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.index)
      ..writeByte(3)
      ..write(obj.realtimeKwTarget)
      ..writeByte(4)
      ..write(obj.engineRpm)
      ..writeByte(5)
      ..write(obj.frequencyHz)
      ..writeByte(6)
      ..write(obj.engineWaterF)
      ..writeByte(7)
      ..write(obj.radiatorWaterF)
      ..writeByte(8)
      ..write(obj.engineOilTempF)
      ..writeByte(9)
      ..write(obj.engineOilPsi)
      ..writeByte(10)
      ..write(obj.panelVolt)
      ..writeByte(11)
      ..write(obj.measuredVolt)
      ..writeByte(12)
      ..write(obj.panelAmp)
      ..writeByte(13)
      ..write(obj.measuredAmp)
      ..writeByte(14)
      ..write(obj.panelKw)
      ..writeByte(15)
      ..write(obj.measuredKw)
      ..writeByte(16)
      ..write(obj.batteryVolt)
      ..writeByte(17)
      ..write(obj.fuelPressure);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestIntervalRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
