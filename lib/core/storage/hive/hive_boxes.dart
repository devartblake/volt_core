import 'package:hive/hive.dart';
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';

class HiveBoxes {
  static late Box<Inspection> inspections;
  static late Box<LoadTestRecord> loadTests;
  static late Box<NameplateData> nameplates;
  static late Box<TestIntervalRecord> testIntervals;

  static Future<void> init() async {
    inspections = await Hive.openBox<Inspection>('inspections');
    loadTests = await Hive.openBox<LoadTestRecord>('load_tests_records');
    nameplates = await Hive.openBox<NameplateData>('nameplate_data');
    testIntervals = await Hive.openBox<TestIntervalRecord>('test_interval_records');
  }
}
