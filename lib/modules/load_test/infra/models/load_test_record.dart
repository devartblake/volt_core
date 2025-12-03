import 'package:hive/hive.dart';

part 'load_test_record.g.dart';

/// A single row from the "Load Test" sheet, linked to an Inspection by `inspectionId`.
@HiveType(typeId: 11) // <-- make sure this is unused elsewhere
class LoadTestRecord extends HiveObject {
  @HiveField(0)
  String id;

  /// Foreign key: the parent inspection's id
  @HiveField(1)
  String inspectionId;

  /// Sequence index on the sheet (0..n), useful for stable ordering
  @HiveField(2)
  int stepIndex;

  /// Generator load percentage for this step (e.g., 25, 50, 75, 100)
  @HiveField(3)
  int loadPercent;

  /// Test duration in minutes for this step
  @HiveField(4)
  int durationMinutes;

  // Electrical readings (optional, keep as strings so techs can enter notes/units)
  @HiveField(5)
  String voltageL1L2;

  @HiveField(6)
  String voltageL2L3;

  @HiveField(7)
  String voltageL1L3;

  @HiveField(8)
  String frequencyHz;

  @HiveField(9)
  String currentA;

  @HiveField(10)
  String measuredKw;

  /// Freeform comments
  @HiveField(11)
  String notes;

  /// Pass/fail for this step
  @HiveField(12)
  bool pass;

  LoadTestRecord({
    required this.id,
    required this.inspectionId,
    required this.stepIndex,
    this.loadPercent = 0,
    this.durationMinutes = 0,
    this.voltageL1L2 = '',
    this.voltageL2L3 = '',
    this.voltageL1L3 = '',
    this.frequencyHz = '',
    this.currentA = '',
    this.measuredKw = '',
    this.notes = '',
    this.pass = true,
  });

  LoadTestRecord copyWith({
    String? id,
    String? inspectionId,
    int? stepIndex,
    int? loadPercent,
    int? durationMinutes,
    String? voltageL1L2,
    String? voltageL2L3,
    String? voltageL1L3,
    String? frequencyHz,
    String? currentA,
    String? measuredKw,
    String? notes,
    bool? pass,
  }) {
    return LoadTestRecord(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      stepIndex: stepIndex ?? this.stepIndex,
      loadPercent: loadPercent ?? this.loadPercent,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      voltageL1L2: voltageL1L2 ?? this.voltageL1L2,
      voltageL2L3: voltageL2L3 ?? this.voltageL2L3,
      voltageL1L3: voltageL1L3 ?? this.voltageL1L3,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      currentA: currentA ?? this.currentA,
      measuredKw: measuredKw ?? this.measuredKw,
      notes: notes ?? this.notes,
      pass: pass ?? this.pass,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'stepIndex': stepIndex,
    'loadPercent': loadPercent,
    'durationMinutes': durationMinutes,
    'voltageL1L2': voltageL1L2,
    'voltageL2L3': voltageL2L3,
    'voltageL1L3': voltageL1L3,
    'frequencyHz': frequencyHz,
    'currentA': currentA,
    'measuredKw': measuredKw,
    'notes': notes,
    'pass': pass,
  };

  static LoadTestRecord fromJson(Map<String, dynamic> json) => LoadTestRecord(
    id: json['id'] as String,
    inspectionId: json['inspectionId'] as String,
    stepIndex: (json['stepIndex'] as num).toInt(),
    loadPercent: (json['loadPercent'] as num?)?.toInt() ?? 0,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    voltageL1L2: json['voltageL1L2'] as String? ?? '',
    voltageL2L3: json['voltageL2L3'] as String? ?? '',
    voltageL1L3: json['voltageL1L3'] as String? ?? '',
    frequencyHz: json['frequencyHz'] as String? ?? '',
    currentA: json['currentA'] as String? ?? '',
    measuredKw: json['measuredKw'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    pass: json['pass'] as bool? ?? true,
  );
}
