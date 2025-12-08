import 'package:hive_flutter/hive_flutter.dart';
import '../../../modules/inspections/infra/models/inspection.dart';
import '../../../modules/load_test/infra/models/load_test_record.dart';
import '../../../modules/inspections/infra/models/nameplate_data.dart';
import '../../../modules/load_test/infra/models/test_interval_record.dart';

Future<void> registerHiveAdapters() async {
  if (!Hive.isAdapterRegistered(InspectionAdapter().typeId)) {
    Hive.registerAdapter(InspectionAdapter());
  }
  if (!Hive.isAdapterRegistered(LoadTestRecordAdapter().typeId)) {
    Hive.registerAdapter(LoadTestRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(NameplateDataAdapter().typeId)) {
    Hive.registerAdapter(NameplateDataAdapter());
  }
  if (!Hive.isAdapterRegistered(TestIntervalRecordAdapter().typeId)) {
    Hive.registerAdapter(TestIntervalRecordAdapter());
  }
}