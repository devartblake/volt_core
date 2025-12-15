import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/storage/file_storage_service.dart';
import 'app_router.dart';
import '../core/theme/app_theme.dart';

/// Root Voltcore application widget.
///
/// - Wires MaterialApp.router
/// - Attaches GoRouter via Riverpod (goRouterProvider)
/// - Applies light/dark themes
class VoltcoreApp extends ConsumerWidget {
  const VoltcoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👇 Get the router from Riverpod
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Voltcore',
      debugShowCheckedModeBanner: false,

      // If AppTheme is implemented, this plugs right in.
      // Otherwise you can temporarily use ThemeData.light() / ThemeData.dark().
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      routerConfig: router,
    );
  }
}

class StorageCleanupService {
  static Future<void> performMaintenance() async {
    // Clean temp files older than 7 days
    await FileStorageService.instance.cleanTempFiles(
      maxAge: Duration(days: 7),
    );

    // Optionally clean cache
    await FileStorageService.instance.cleanCache();

    if (kDebugMode) {
      await FileStorageService.instance.printDebugInfo();
    }
  }
}