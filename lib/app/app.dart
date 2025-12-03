import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import '../core/theme/app_theme.dart';

/// Root Voltcore application widget.
///
/// This is the single place where we:
/// - Wire MaterialApp.router
/// - Attach the global GoRouter
/// - Apply light/dark themes
class VoltcoreApp extends ConsumerWidget {
  const VoltcoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Voltcore',
      debugShowCheckedModeBanner: false,

      // If you already have AppTheme implemented, this will plug right in.
      // Otherwise, you can temporarily replace these with ThemeData.light()
      // and ThemeData.dark().
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: ThemeMode.system,

      routerConfig: appRouter,
    );
  }
}