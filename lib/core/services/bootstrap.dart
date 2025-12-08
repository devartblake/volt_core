// Central bootstrap for core services (Supabase, Hive, etc.)
// Call this once before runApp() in main.dart.

import 'package:flutter/foundation.dart';

import 'hive/hive_service.dart';
import 'supabase/supabase_service.dart';

Future<void> initCoreServices() async {
  // Order can matter if some services depend on others.
  // Right now, they’re independent.
  await HiveService.init();
  await SupabaseService.init();

  if (kDebugMode) {
    debugPrint('[CoreServices] initialization completed');
  }
}