import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/storage/file_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import 'app_router.dart';

/// Root Voltcore application widget.
///
/// - Wires MaterialApp.router
/// - Attaches GoRouter via Riverpod (goRouterProvider)
/// - Applies light/dark themes
class VoltcoreApp extends ConsumerWidget {
  const VoltcoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Voltcore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class StorageCleanupService {
  static Future<void> performMaintenance() async {
    // Browser builds use Hive/WebFileStore rather than filesystem directories.
    // `path_provider` has no web implementation for these APIs.
    if (kIsWeb) return;

    // Clean temp files older than 7 days
    await FileStorageService.instance.cleanTempFiles(maxAge: Duration(days: 7));

    // Optionally clean cache
    await FileStorageService.instance.cleanCache();

    if (kDebugMode) {
      await FileStorageService.instance.printDebugInfo();
    }
  }
}
