import 'package:hive/hive.dart';
part 'nameplate_data.g.dart';

@HiveType(typeId: 12)
class NameplateData extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String inspectionId;

  // Core fields
  @HiveField(2) String generatorMfr;
  @HiveField(3) String generatorModel;
  @HiveField(4) String generatorSn;
  @HiveField(5) String kva;
  @HiveField(6) String kw;
  @HiveField(7) String volts;
  @HiveField(8) String amps;
  @HiveField(9) String phase;
  @HiveField(10) String cycles;
  @HiveField(11) String rpm;

  @HiveField(12) String controlMfr;
  @HiveField(13) String controlModel;
  @HiveField(14) String controlSn;

  @HiveField(15) String governorMfr;
  @HiveField(16) String governorModel;
  @HiveField(17) String governorSn;

  @HiveField(18) String regulatorMfr;
  @HiveField(19) String regulatorModel;
  @HiveField(20) String regulatorSn;

  // Fuel monitoring
  @HiveField(21) String volumeGal;
  @HiveField(22) String ullageGal;
  @HiveField(23) String ullage90Gal;
  @HiveField(24) String tcVolumeGal;
  @HiveField(25) String heightGal;
  @HiveField(26) String waterGal;
  @HiveField(27) String waterInches;
  @HiveField(28) String tempF;
  @HiveField(29) String time;

  @HiveField(30) String comments;
  @HiveField(31) String deficiencies;

  NameplateData({
    required this.id,
    required this.inspectionId,
    this.generatorMfr = '',
    this.generatorModel = '',
    this.generatorSn = '',
    this.kva = '',
    this.kw = '',
    this.volts = '',
    this.amps = '',
    this.phase = '',
    this.cycles = '',
    this.rpm = '',
    this.controlMfr = '',
    this.controlModel = '',
    this.controlSn = '',
    this.governorMfr = '',
    this.governorModel = '',
    this.governorSn = '',
    this.regulatorMfr = '',
    this.regulatorModel = '',
    this.regulatorSn = '',
    this.volumeGal = '',
    this.ullageGal = '',
    this.ullage90Gal = '',
    this.tcVolumeGal = '',
    this.heightGal = '',
    this.waterGal = '',
    this.waterInches = '',
    this.tempF = '',
    this.time = '',
    this.comments = '',
    this.deficiencies = '',
  });
}
