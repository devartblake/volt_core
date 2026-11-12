import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';

/// Saturday 7 Nov 2026, 10:00 local.
final kNow = DateTime(2026, 11, 7, 10);

/// Local midnight [days] from today (negative = past).
DateTime day(int days) => DateTime(2026, 11, 7 + days);

ReadinessInspection insp(
  String id, {
  int ago = 10,
  String grade = 'Green',
  int? dueIn,
  String site = 'Q_001',
  String make = 'Kohler',
  String model = '250REOZD',
  String serial = 'SN1',
  String fuel = 'Diesel',
  bool load = false,
  String address = '1 Main St',
}) =>
    ReadinessInspection(
      id: id,
      serviceDate: day(-ago),
      siteCode: site,
      address: address,
      grade: grade,
      nextDueAt: dueIn == null ? null : day(dueIn),
      make: make,
      model: model,
      serial: serial,
      fuelType: fuel,
      loadbankDone: load,
    );

ReadinessInputs oneUnit(
  ReadinessInspection i, {
  List<ReadinessMaintenance> maintenance = const [],
  List<ReadinessTask> tasks = const [],
  List<ReadinessJobNeed> jobNeeds = const [],
}) =>
    ReadinessInputs(
      inspections: [i],
      maintenance: maintenance,
      tasks: tasks,
      jobNeeds: jobNeeds,
    );
