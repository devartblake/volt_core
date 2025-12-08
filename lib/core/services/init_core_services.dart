import 'package:flutter/widgets.dart';

import 'hive/hive_service.dart';
import 'supabase/supabase_service.dart';

/// Initialize all core services *before* running the app.
///
/// Call this from `main()`:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initCoreServices();
///   runApp(const ProviderScope(child: VoltcoreApp()));
/// }
/// ```
Future<void> initCoreServices() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();
  await SupabaseService.init();
}