import 'package:hive/hive.dart';
part 'test_interval_record.g.dart';

@HiveType(typeId: 13)
class TestIntervalRecord extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String inspectionId;
  @HiveField(2) int index;

  // Simplified set of the many columns in your sheet
  @HiveField(3) String realtimeKwTarget;
  @HiveField(4) String engineRpm;
  @HiveField(5) String frequencyHz;
  @HiveField(6) String engineWaterF;
  @HiveField(7) String radiatorWaterF;
  @HiveField(8) String engineOilTempF;
  @HiveField(9) String engineOilPsi;
  @HiveField(10) String panelVolt;
  @HiveField(11) String measuredVolt;
  @HiveField(12) String panelAmp;
  @HiveField(13) String measuredAmp;
  @HiveField(14) String panelKw;
  @HiveField(15) String measuredKw;
  @HiveField(16) String batteryVolt;
  @HiveField(17) String fuelPressure;

  TestIntervalRecord({
    required this.id,
    required this.inspectionId,
    required this.index,
    this.realtimeKwTarget = '',
    this.engineRpm = '',
    this.frequencyHz = '',
    this.engineWaterF = '',
    this.radiatorWaterF = '',
    this.engineOilTempF = '',
    this.engineOilPsi = '',
    this.panelVolt = '',
    this.measuredVolt = '',
    this.panelAmp = '',
    this.measuredAmp = '',
    this.panelKw = '',
    this.measuredKw = '',
    this.batteryVolt = '',
    this.fuelPressure = '',
  });
}
