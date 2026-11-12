import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presenter/widgets/offline_banner.dart';
import '../presenter/widgets/sync_status_indicator.dart';

/// Default cap on page body width; keeps portrait and landscape balanced.
const double kDefaultMaxContentWidth = 960;

/// Centres [child] with equal side margins once the space exceeds [maxWidth].
///
/// Uses padding rather than an Align/ConstrainedBox so the child keeps tight
/// constraints (a body that fills the screen still fills it).
class _CenteredBody extends StatelessWidget {
  const _CenteredBody({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth - maxWidth;
        if (!extra.isFinite || extra <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }
}

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
    this.sectionTabs = const [],
    this.bottomNav,
    this.onSearch,
  });

  /// Opens global search. When set, [AppPage] puts a search button in every
  /// page's app bar.
  final VoidCallback? onSearch;

  /// Bottom navigation bar for top-level pages (phone, or tablets set to the
  /// bottom-bar style). A page's own `bottomBar` takes its place.
  final Widget? bottomNav;

  /// Sibling pages of the section the current page belongs to (for example
  /// Jobs / Maintenance / Schedule / Archive). When there are two or more,
  /// [AppPage] shows them as tabs under its app bar, so related pages are one
  /// tap apart without each needing its own menu entry.
  final List<SectionTab> sectionTabs;

  /// True when navigation is a slide-out drawer rather than a fixed rail.
  final bool isCompact;

  /// The drawer to attach to the page's Scaffold when [isCompact]. Null on wide
  /// layouts, where the shell already shows a persistent rail beside the page.
  final Widget? drawer;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      isCompact != oldWidget.isCompact ||
      drawer != oldWidget.drawer ||
      bottomNav != oldWidget.bottomNav ||
      (onSearch == null) != (oldWidget.onSearch == null) ||
      !_sameTabs(sectionTabs, oldWidget.sectionTabs);
}

/// One tab in a page's section bar.
@immutable
class SectionTab {
  const SectionTab({
    required this.label,
    required this.icon,
    required this.route,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool selected;
}

bool _sameTabs(List<SectionTab> a, List<SectionTab> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].route != b[i].route || a[i].selected != b[i].selected) {
      return false;
    }
  }
  return true;
}

/// Horizontal chip row under the app bar for switching between a section's
/// pages.
class _SectionTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _SectionTabBar(this.tabs);

  final List<SectionTab> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Section pages',
      child: SizedBox(
        height: preferredSize.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final tab = tabs[i];
            final scheme = Theme.of(context).colorScheme;
            // Explicit colours: the theme's chip label was nearly invisible
            // on the selected (tinted) background.
            final fg = tab.selected
                ? scheme.onSecondaryContainer
                : scheme.onSurface;
            return ChoiceChip(
              avatar: Icon(tab.icon, size: 18, color: fg),
              label: Text(tab.label, style: TextStyle(color: fg)),
              selectedColor: scheme.secondaryContainer,
              showCheckmark: false,
              selected: tab.selected,
              // Never null: a selected chip with no handler counts as disabled and
              // is drawn greyed out.
              onSelected: (_) {
                if (!tab.selected) context.go(tab.route);
              },
            );
          },
        ),
      ),
    );
  }
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
    this.showSearch = true,
    this.appBarBottom,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.maxContentWidth = kDefaultMaxContentWidth,
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

  /// Whether the app bar shows the global search button (when the shell
  /// provides one). Off for pages that already are a search.
  final bool showSearch;

  /// Widget shown at the bottom of the app bar, e.g. a TabBar.
  final PreferredSizeWidget? appBarBottom;

  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  /// Widest the body is allowed to get. On a tablet in landscape (or a desktop
  /// window) full-width forms and lists stretch into hard-to-read lines, so the
  /// body is centred with equal margins instead. Pass `double.infinity` for
  /// content that should bleed edge to edge.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final scope = AppShellScope.maybeOf(context);
    final drawer = scope?.isCompact == true ? scope?.drawer : null;
    final tabs = scope?.sectionTabs ?? const <SectionTab>[];
    // A page that brings its own bottom (a TabBar) keeps it.
    final bottom =
        appBarBottom ?? (tabs.length >= 2 ? _SectionTabBar(tabs) : null);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        leading: leading,
        bottom: bottom,
        actions: [
          ...actions,
          if (scope?.onSearch != null && showSearch)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: scope!.onSearch,
            ),
          if (showSyncStatus) ...const [
            SyncStatusIndicator(),
            SizedBox(width: 4),
          ],
        ],
      ),
      drawer: drawer,
      body: Column(
        children: [
          if (showSyncStatus) const OfflineBanner(),
          Expanded(
            child: _CenteredBody(maxWidth: maxContentWidth, child: body),
          ),
        ],
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation: fabLocation,
      bottomNavigationBar: bottomBar ?? scope?.bottomNav,
    );
  }
}
