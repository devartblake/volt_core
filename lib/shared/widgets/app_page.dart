import 'package:flutter/material.dart';

import '../presenter/widgets/sync_status_indicator.dart';

/// Navigation chrome published by the surrounding app shell.
///
/// The shell decides *how* navigation is presented (drawer on phones, rail on
/// wide screens) and hands the pieces down; [AppPage] decides where they go.
/// Pages outside a shell (login, 403, debug) simply find no scope and render a
/// plain page.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.isCompact,
    required this.drawer,
    required super.child,
  });

  /// True when navigation is a slide-out drawer rather than a fixed rail.
  final bool isCompact;

  /// The drawer to attach to the page's Scaffold when [isCompact]. Null on wide
  /// layouts, where the shell already shows a persistent rail beside the page.
  final Widget? drawer;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      isCompact != oldWidget.isCompact || drawer != oldWidget.drawer;
}

/// The single page chrome for the app.
///
/// Every routed screen returns an [AppPage] instead of building its own
/// `Scaffold` + `AppBar`. Previously both the shell and the page drew an app
/// bar, so most screens showed two stacked headers (and five showed two
/// drawers). Centralising it here means:
///
/// * exactly one app bar, titled by the page,
/// * exactly one drawer, owned by the shell,
/// * the sync indicator present on every screen without each page adding it.
///
/// ```dart
/// return AppPage(
///   title: 'Inspections',
///   actions: [IconButton(...)],
///   fab: FloatingActionButton(...),
///   body: ListView(...),
/// );
/// ```
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.fab,
    this.fabLocation,
    this.bottomBar,
    this.bottomAppBarHeight,
    this.titleWidget,
    this.leading,
    this.showSyncStatus = true,
    this.appBarBottom,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  /// Page title shown in the app bar. Ignored when [titleWidget] is given.
  final String title;

  /// Optional rich title (e.g. title + subtitle) replacing the plain [title].
  final Widget? titleWidget;

  final Widget body;

  /// Trailing app-bar actions. The sync indicator is appended automatically
  /// unless [showSyncStatus] is false.
  final List<Widget> actions;

  final Widget? fab;
  final FloatingActionButtonLocation? fabLocation;

  /// Persistent bar pinned to the bottom (e.g. a form's Save bar).
  final Widget? bottomBar;
  final double? bottomAppBarHeight;

  /// Overrides the automatic leading widget (back arrow / drawer button).
  final Widget? leading;

  final bool showSyncStatus;

  /// Widget shown at the bottom of the app bar, e.g. a TabBar.
  final PreferredSizeWidget? appBarBottom;

  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final scope = AppShellScope.maybeOf(context);
    final drawer = scope?.isCompact == true ? scope?.drawer : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        leading: leading,
        bottom: appBarBottom,
        actions: [
          ...actions,
          if (showSyncStatus) ...const [
            SyncStatusIndicator(),
            SizedBox(width: 4),
          ],
        ],
      ),
      drawer: drawer,
      body: body,
      floatingActionButton: fab,
      floatingActionButtonLocation: fabLocation,
      bottomNavigationBar: bottomBar,
    );
  }
}
