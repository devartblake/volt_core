import 'package:hive/hive.dart';

// -------------------------------
// Import Hive model classes
// -------------------------------
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';

/// Central definition of box names (single source of truth).
class HiveBoxNames {
  static const inspections = 'inspections';
  static const loadTests = 'load_tests_records';
  static const nameplates = 'nameplate_data';
  static const testIntervals = 'test_interval_records';
}

/// Strongly-typed access to Hive boxes.
///
/// These fields are wired during app startup by calling:
///   await openCoreHiveBoxes();
///
/// NOTE: We intentionally *do not* call Hive.openBox() directly
/// here — that is the job of HiveService, not the storage layer.
class HiveBoxes {
  static late Box<Inspection> inspections;
  static late Box<LoadTestRecord> loadTests;
  static late Box<NameplateData> nameplates;
  static late Box<TestIntervalRecord> testIntervals;
}

/// Called by HiveService during initialization.
///
/// Ensures boxes are opened exactly once and assigned to HiveBoxes.
Future<void> openCoreHiveBoxes() async {
  HiveBoxes.inspections =
  await Hive.openBox<Inspection>(HiveBoxNames.inspections);

  HiveBoxes.loadTests =
  await Hive.openBox<LoadTestRecord>(HiveBoxNames.loadTests);

  HiveBoxes.nameplates =
  await Hive.openBox<NameplateData>(HiveBoxNames.nameplates);

  HiveBoxes.testIntervals =
  await Hive.openBox<TestIntervalRecord>(HiveBoxNames.testIntervals);
}