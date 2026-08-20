import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'hive/hive_service.dart';
import 'notifications/notification_service.dart';
import 'forms/form_draft_service.dart';
import 'photos/photo_repository.dart';
import 'storage/file_storage_service.dart';
import 'storage/web_file_store.dart';
import 'supabase/supabase_service.dart';
import 'sync/sync_service.dart';

// Initialize all core services *before* running the app.
///
/// This function:
/// 1. Creates the app's data directory tree (hive/, pdfs/, signatures/, exports/, temp/)
/// 2. Initializes Hive and registers ALL adapters
/// 3. Initializes Supabase client
/// 4. Starts the offline-first sync engine (drains queued changes to the cloud)
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

  // Create the full storage directory tree so every kind of data the app
  // produces (Hive DB, PDFs, signatures, exports, temp) has its folder:
  // dev (desktop) -> <project>/dev_data/, production -> on-device app data.
  await FileStorageService.instance.ensureDirectories();

  // Initialize Hive and register adapters
  // CRITICAL: This must run BEFORE any boxes are opened
  await HiveService.init();

  // Open the adapter-free photo-attachments box.
  await PhotoRepository.instance.init();

  // Open the form-drafts box so unsaved form work survives navigation.
  await FormDraftService.instance.init();

  // On web there is no filesystem: signature/photo bytes live in the
  // WebFileStore (IndexedDB-backed Hive box). Open it so synchronous reads
  // (thumbnails, PDF embedding) work.
  if (kIsWeb) {
    await WebFileStore.instance.init();
  }

  // Initialize Supabase
  await SupabaseService.init();

  // Start the offline-first sync engine. This opens the durable outbox and
  // begins draining queued record/file changes to Supabase whenever the device
  // is online. It never throws, so it can't block startup.
  await SyncService.instance.init();

  // Initialize local notifications (schedule reminders). Permission is
  // requested later, in context, when the first reminder is scheduled.
  await NotificationService.instance.init();

  if (kDebugMode) {
    debugPrint('[CoreServices] Initialization completed');
  }
}
