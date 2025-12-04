// Single function to register all Hive TypeAdapters.
// Keep all adapter registration in one place to avoid "duplicate typeId"
// issues across modules.

import 'package:hive_flutter/hive_flutter.dart';

/// Register all adapters here.
///
/// Example:
///   Hive.registerAdapter(InspectionModelAdapter());
///   Hive.registerAdapter(MaintenanceJobModelAdapter());
Future<void> registerHiveAdapters() async {
  // TODO: add your generated adapters here.
  //
  // This file is intentionally empty so it compiles even before
  // you've generated Hive adapters for your models.
  //
  // When you run build_runner and get `*.g.dart` adapters, just:
  //   import 'package:voltcore/modules/inspections/infra/models/inspection_model.dart';
  //   Hive.registerAdapter(InspectionModelAdapter());
}