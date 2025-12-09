import 'package:flutter/material.dart';

/// Responsive scaffold that provides consistent page layout.
///
/// Navigation is handled by app shells (DefaultShell, TechShell, AdminShell).
/// This widget only provides the scaffold structure (AppBar, body, FAB, etc.)
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.fab,
    this.fabLocation,
    this.bottomBar,
    // Deprecated: kept for backwards compatibility but not used
    @Deprecated('Navigation is handled by shells') this.badges,
    @Deprecated('Navigation is handled by shells') this.userProfile,
    @Deprecated('Navigation is handled by shells') this.onSwitchTenant,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? fab;
  final FloatingActionButtonLocation? fabLocation;
  final Widget? bottomBar;

  /// Deprecated: shells handle badges
  final Map<String, int>? badges;

  /// Deprecated: shells handle user profile
  final dynamic userProfile;

  /// Deprecated: shells handle tenant switching
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    // Simple scaffold - shells handle the navigation drawer
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: fab,
      floatingActionButtonLocation: fabLocation,
      bottomNavigationBar: bottomBar,
    );
  }
}