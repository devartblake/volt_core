import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'hive/hive_service.dart';
import 'supabase/supabase_service.dart';

// Initialize all core services *before* running the app.
///
/// This function:
/// 1. Initializes Hive and registers ALL adapters
/// 2. Initializes Supabase client
///
/// Call this from `main()`:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Env.load();
///   await initCoreServices();
///   await MaintenanceBoxes.init(); // Safe to open boxes now
///   runApp(const ProviderScope(child: VoltcoreApp()));
/// }
/// ```
Future<void> initCoreServices() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    debugPrint('[CoreServices] Starting initialization...');
  }

  // Initialize Hive and register adapters
  // CRITICAL: This must run BEFORE any boxes are opened
  await HiveService.init();

  // Initialize Supabase
  await SupabaseService.init();

  if (kDebugMode) {
    debugPrint('[CoreServices] Initialization completed');
  }
}
