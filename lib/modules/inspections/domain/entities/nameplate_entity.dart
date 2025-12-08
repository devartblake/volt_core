/// Domain entity for nameplate & fuel monitoring data.
class NameplateEntity {
  final String id;
  final String inspectionId;

  final String generatorMfr;
  final String generatorModel;
  final String generatorSn;
  final String kva;
  final String kw;
  final String volts;
  final String amps;
  final String phase;
  final String cycles;
  final String rpm;

  final String controlMfr;
  final String controlModel;
  final String controlSn;

  final String governorMfr;
  final String governorModel;
  final String governorSn;

  final String regulatorMfr;
  final String regulatorModel;
  final String regulatorSn;

  // Fuel monitoring
  final String volumeGal;
  final String ullageGal;
  final String ullage90Gal;
  final String tcVolumeGal;
  final String heightGal;
  final String waterGal;
  final String waterInches;
  final String tempF;
  final String time;

  final String comments;
  final String deficiencies;

  const NameplateEntity({
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

  NameplateEntity copyWith({
    String? id,
    String? inspectionId,
    String? generatorMfr,
    String? generatorModel,
    String? generatorSn,
    String? kva,
    String? kw,
    String? volts,
    String? amps,
    String? phase,
    String? cycles,
    String? rpm,
    String? controlMfr,
    String? controlModel,
    String? controlSn,
    String? governorMfr,
    String? governorModel,
    String? governorSn,
    String? regulatorMfr,
    String? regulatorModel,
    String? regulatorSn,
    String? volumeGal,
    String? ullageGal,
    String? ullage90Gal,
    String? tcVolumeGal,
    String? heightGal,
    String? waterGal,
    String? waterInches,
    String? tempF,
    String? time,
    String? comments,
    String? deficiencies,
  }) {
    return NameplateEntity(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      generatorMfr: generatorMfr ?? this.generatorMfr,
      generatorModel: generatorModel ?? this.generatorModel,
      generatorSn: generatorSn ?? this.generatorSn,
      kva: kva ?? this.kva,
      kw: kw ?? this.kw,
      volts: volts ?? this.volts,
      amps: amps ?? this.amps,
      phase: phase ?? this.phase,
      cycles: cycles ?? this.cycles,
      rpm: rpm ?? this.rpm,
      controlMfr: controlMfr ?? this.controlMfr,
      controlModel: controlModel ?? this.controlModel,
      controlSn: controlSn ?? this.controlSn,
      governorMfr: governorMfr ?? this.governorMfr,
      governorModel: governorModel ?? this.governorModel,
      governorSn: governorSn ?? this.governorSn,
      regulatorMfr: regulatorMfr ?? this.regulatorMfr,
      regulatorModel: regulatorModel ?? this.regulatorModel,
      regulatorSn: regulatorSn ?? this.regulatorSn,
      volumeGal: volumeGal ?? this.volumeGal,
      ullageGal: ullageGal ?? this.ullageGal,
      ullage90Gal: ullage90Gal ?? this.ullage90Gal,
      tcVolumeGal: tcVolumeGal ?? this.tcVolumeGal,
      heightGal: heightGal ?? this.heightGal,
      waterGal: waterGal ?? this.waterGal,
      waterInches: waterInches ?? this.waterInches,
      tempF: tempF ?? this.tempF,
      time: time ?? this.time,
      comments: comments ?? this.comments,
      deficiencies: deficiencies ?? this.deficiencies,
    );
  }
}
