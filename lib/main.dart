import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'core/data/supabase_client.dart';
import 'core/services/bootstrap.dart';
import 'core/services/hive/hive_service.dart';
import 'core/services/supabase/supabase_service.dart';
import 'core/storage/hive/hive_boxes.dart';
import 'modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';

void main() async {
  // Ensure Flutte is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  await initCoreServices();
  await HiveService.init();
  await SupabaseService.init();
  HiveBoxes();

  // Hive.registerAdapter(MaintenanceRecordAdapter());
  // Hive.registerAdapter(InspectionAdapter());
  // Hive.registerAdapter(LoadTestRecordAdapter());
  // Hive.registerAdapter(NameplateDataAdapter());
  // Hive.registerAdapter(TestIntervalRecordAdapter());

  // Initialize all boxes
  try {
    await MaintenanceBoxes.init();
    // Add other box initializations here:
    // await InspectionBoxes.init();
    // await OtherBoxes.init();

    debugPrint('✅ All Hive boxes initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Hive boxes: $e');
    // Handle initialization error - maybe show error screen
  }

  await VoltcoreSupabase.init(
    url: 'https://YOUR_PROJECT_ID.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(
    const ProviderScope(
      child: VoltcoreApp()
    ),
  );
}
