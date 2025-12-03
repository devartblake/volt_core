// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'load_test_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoadTestRecordAdapter extends TypeAdapter<LoadTestRecord> {
  @override
  final int typeId = 11;

  @override
  LoadTestRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoadTestRecord(
      id: fields[0] as String,
      inspectionId: fields[1] as String,
      stepIndex: fields[2] as int,
      loadPercent: fields[3] as int,
      durationMinutes: fields[4] as int,
      voltageL1L2: fields[5] as String,
      voltageL2L3: fields[6] as String,
      voltageL1L3: fields[7] as String,
      frequencyHz: fields[8] as String,
      currentA: fields[9] as String,
      measuredKw: fields[10] as String,
      notes: fields[11] as String,
      pass: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LoadTestRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inspectionId)
      ..writeByte(2)
      ..write(obj.stepIndex)
      ..writeByte(3)
      ..write(obj.loadPercent)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.voltageL1L2)
      ..writeByte(6)
      ..write(obj.voltageL2L3)
      ..writeByte(7)
      ..write(obj.voltageL1L3)
      ..writeByte(8)
      ..write(obj.frequencyHz)
      ..writeByte(9)
      ..write(obj.currentA)
      ..writeByte(10)
      ..write(obj.measuredKw)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.pass);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadTestRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
