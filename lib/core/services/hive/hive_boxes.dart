import 'package:hive/hive.dart';

import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';
import '../../../modules/schedule/infra/models/schedule_task.dart';

/// Central registry for all Hive boxes used by Voltcore.
///
/// This is where we open boxes once and keep static refs for the app.
///
/// Called from [HiveService.init].
class HiveBoxes {
  HiveBoxes._(); // no instances

  // Box names – keep them in one place to avoid typos.
  static const String inspectionsBoxName = 'inspections';
  static const String loadTestsBoxName = 'load_tests_records';
  static const String nameplatesBoxName = 'nameplate_data';
  static const String testIntervalsBoxName = 'test_interval_records';
  static const String scheduledTasksBoxName = 'scheduled_tasks';

  static late Box<dynamic> appSettings;
  static late Box<Inspection> inspections;
  static late Box<LoadTestRecord> loadTests;
  static late Box<NameplateData> nameplates;
  static late Box<TestIntervalRecord> testIntervals;
  static late Box<ScheduledTask> scheduledTasks;

  /// Open all core boxes.
  ///
  /// This is called once from [HiveService.init].
  static Future<void> init() async {
    inspections = await Hive.openBox<Inspection>(inspectionsBoxName);
    loadTests = await Hive.openBox<LoadTestRecord>(loadTestsBoxName);
    nameplates = await Hive.openBox<NameplateData>(nameplatesBoxName);
    testIntervals = await Hive.openBox<TestIntervalRecord>(testIntervalsBoxName);
    scheduledTasks = await Hive.openBox<ScheduledTask>(scheduledTasksBoxName);

    if (!Hive.isBoxOpen('app_settings')) {
      appSettings = await Hive.openBox<dynamic>('app_settings');
    }
  }

  /// Optional convenience methods if you want to open lazily later.
  static Future<Box<Inspection>> openInspectionsIfNeeded() async {
    if (!Hive.isBoxOpen(inspectionsBoxName)) {
      inspections = await Hive.openBox<Inspection>(inspectionsBoxName);
    }
    return inspections;
  }

  static Future<Box<LoadTestRecord>> openLoadTestsIfNeeded() async {
    if (!Hive.isBoxOpen(loadTestsBoxName)) {
      loadTests = await Hive.openBox<LoadTestRecord>(loadTestsBoxName);
    }
    return loadTests;
  }

  static Future<Box<NameplateData>> openNameplatesIfNeeded() async {
    if (!Hive.isBoxOpen(nameplatesBoxName)) {
      nameplates = await Hive.openBox<NameplateData>(nameplatesBoxName);
    }
    return nameplates;
  }

  static Future<Box<TestIntervalRecord>> openTestIntervalsIfNeeded() async {
    if (!Hive.isBoxOpen(testIntervalsBoxName)) {
      testIntervals =
      await Hive.openBox<TestIntervalRecord>(testIntervalsBoxName);
    }
    return testIntervals;
  }

  static Future<Box<ScheduledTask>> openScheduledTasksIfNeeded() async {
    if (!Hive.isBoxOpen(scheduledTasksBoxName)) {
      scheduledTasks = await Hive.openBox<ScheduledTask>(scheduledTasksBoxName);
    }
    return scheduledTasks;
  }

  /// Optional: close all boxes on app shutdown, if you want.
  static Future<void> closeAll() async {
    if (Hive.isBoxOpen(inspectionsBoxName)) {
      await inspections.close();
    }
    if (Hive.isBoxOpen(loadTestsBoxName)) {
      await loadTests.close();
    }
    if (Hive.isBoxOpen(nameplatesBoxName)) {
      await nameplates.close();
    }
    if (Hive.isBoxOpen(testIntervalsBoxName)) {
      await testIntervals.close();
    }
    if (Hive.isBoxOpen(scheduledTasksBoxName)) {  // ⭐ ADDED
      await scheduledTasks.close();
    }
  }
}
