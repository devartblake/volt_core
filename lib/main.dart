import 'package:flutter/foundation.dart';       // for debugPrint
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/configs/env.dart';
import 'core/data/supabase_client.dart';
import 'core/services/bootstrap.dart';
import 'core/services/hive/hive_service.dart';
import 'core/services/supabase/supabase_service.dart';
import 'core/storage/hive/hive_boxes.dart';
import 'modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';
import 'modules/maintenance/infra/models/maintenance_record.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();

  // Initialize Hive
  await Hive.initFlutter();

  // Your other core services
  await initCoreServices();
  await HiveService.init();
  await SupabaseService.init();

  // This likely sets up other Hive boxes / adapters
  HiveBoxes();

  // Register ALL your Hive adapters
  Hive.registerAdapter(MaintenanceRecordAdapter());
  // Hive.registerAdapter(InspectionAdapter()); // If you have one
  // ... register any other adapters

  // Initialize ALL your Hive boxes
  await MaintenanceBoxes.init();
  // await InspectionBoxes.init(); // If you have one
  // ... initialize any other boxes

  runApp(
    const ProviderScope(
      child: VoltcoreApp(),
    ),
  );
}
