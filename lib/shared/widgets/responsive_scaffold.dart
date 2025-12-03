import 'package:flutter/material.dart';
import '../../app/app_drawer.dart'; // for AppDrawer + kCompactBreakpoint

/// Scaffold that adapts:
/// - Compact: AppBar + modal Drawer
/// - Wide:    Persistent NavigationRail at left + content at right
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.fab,
    this.fabLocation,
    this.bottomBar,
    this.badges,
    this.userProfile,
    this.onSwitchTenant,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? fab;
  final FloatingActionButtonLocation? fabLocation;
  final Widget? bottomBar;

  /// Route -> count (passed to AppDrawer)
  final Map<String, int>? badges;

  /// Profile (passed to AppDrawer)
  final AppUserProfile? userProfile;

  /// Tenant switch callback (passed to AppDrawer)
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < kCompactBreakpoint;

    if (isCompact) {
      return Scaffold(
        appBar: appBar,
        drawer: AppDrawer(
          badges: badges,
          userProfile: userProfile,
          onSwitchTenant: onSwitchTenant,
          onTapAny: () {}, // AppDrawer closes itself via Navigator.maybePop
        ),
        body: body,
        floatingActionButton: fab,
        floatingActionButtonLocation: fabLocation,
        bottomNavigationBar: bottomBar,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          AppDrawer(
            badges: badges,
            userProfile: userProfile,
            onSwitchTenant: onSwitchTenant,
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation: fabLocation,
      bottomNavigationBar: bottomBar,
    );
  }
}
