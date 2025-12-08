// lib/main.dart
import 'package:flutter/foundation.dart';       // for debugPrint
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

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Your other core services
  await initCoreServices();
  await HiveService.init();
  await SupabaseService.init();

  // This likely sets up other Hive boxes / adapters
  HiveBoxes();

  // Initialize maintenance box ONCE here
  try {
    await MaintenanceBoxes.init();
    debugPrint('✅ Maintenance box initialized successfully');
  } catch (e, st) {
    debugPrint('❌ Error initializing MaintenanceBoxes: $e');
    debugPrint('$st');
    // Optional: you could show an error screen instead of running the app
  }

  runApp(
    const ProviderScope(
      child: VoltcoreApp(),
    ),
  );
}
