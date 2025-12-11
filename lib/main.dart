import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/configs/env.dart';
import 'core/services/init_core_services.dart';
import 'core/storage/hive/hive_boxes.dart';
import 'modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 VOLTCORE INITIALIZATION');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  try {
    // 1) Load environment-specific .env file
    if (kDebugMode) debugPrint('[1/4] Loading environment configuration...');
    await Env.load();
    if (kDebugMode) {
      debugPrint('      ✅ Environment: ${Env.current}');
      debugPrint('      ✅ File: ${Env.filename}');
    }

    // 2) Initialize core services (Hive + Supabase)
    //    This registers ALL Hive adapters and initializes Supabase
    if (kDebugMode) debugPrint('[2/4] Initializing core services...');
    await initCoreServices();
    if (kDebugMode) debugPrint('      ✅ HiveService initialized (adapters registered)');
    if (kDebugMode) debugPrint('      ✅ SupabaseService initialized');

    // 3) Initialize domain-specific Hive boxes
    //    Safe to open boxes now that adapters are registered
    if (kDebugMode) debugPrint('[3/4] Opening Hive boxes...');
    await MaintenanceBoxes.init();
    HiveBoxes();
    if (kDebugMode) debugPrint('      ✅ MaintenanceBoxes initialized');
    if (kDebugMode) debugPrint('      ✅ HiveBoxes initialized');

    // 4) Launch app
    if (kDebugMode) debugPrint('[4/4] Launching app...');
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ All services initialized successfully');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    runApp(
      const ProviderScope(
        child: VoltcoreApp(),
      ),
    );
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ INITIALIZATION FAILED');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    rethrow;
  }

  // Clean up in background
  StorageCleanupService.performMaintenance();
}