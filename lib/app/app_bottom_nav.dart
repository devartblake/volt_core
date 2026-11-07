import 'package:flutter/material.dart';

import 'nav_config.dart';

/// Bottom navigation: one labelled destination per section.
///
/// * **Phone** - the first four sections plus a "More" button that opens the
///   full drawer (every page, quick actions, profile). Reachable with a thumb,
///   unlike the slide-out menu alone.
/// * **Tablet, bottom-bar style** (Settings > Appearance) - every section, no
///   "More" needed, in place of the side rail.
///
/// Shown only on a section's top-level pages; detail and form screens keep
/// their own back arrow and bottom bars.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.sections,
    required this.location,
    this.maxDestinations = 5,
    this.showMore = false,
  });

  /// Sections the signed-in role may see, in menu order.
  final List<NavSection> sections;

  /// Current router location.
  final String location;

  /// Most destinations the bar can hold, counting "More". A bar that needs
  /// more than this shows the first `maxDestinations - 1` sections and "More".
  final int maxDestinations;

  /// Adds a "More" button (opening the drawer) when the sections do not all
  /// fit. Leave false where there is no drawer; the bar must then fit every
  /// section.
  final bool showMore;

  /// Whether [location] is exactly one of the menu pages. Detail routes such as
  /// `/inspections/123` are not, so they get no bottom bar.
  static bool isTopLevel(List<NavSection> sections, String location) {
    final path = location.length > 1 && location.endsWith('/')
        ? location.substring(0, location.length - 1)
        : location;
    return sections.any((s) => s.items.any((i) => i.route == path));
  }

  @override
  Widget build(BuildContext context) {
    final overflow = showMore && sections.length > maxDestinations;
    final primary = overflow
        ? sections.take(maxDestinations - 1).toList()
        : sections;
    if (primary.length < 2) return const SizedBox.shrink();

    final selectedItem = selectedNavItemForRoute(location, sections);
    var selected = sections.indexWhere(
      (s) => s.items.any((i) => i.route == selectedItem?.route),
    );
    // A page that lives behind "More" highlights "More".
    if (selected < 0 || selected >= primary.length) {
      selected = overflow ? primary.length : 0;
    }

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: NavigationBar(
        height: 68,
        selectedIndex: selected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            goToRoute(context, primary[i].items.first.route);
          } else {
            Scaffold.maybeOf(context)?.openDrawer();
          }
        },
        destinations: [
          for (final s in primary)
            NavigationDestination(
              icon: Icon(s.destinationIcon),
              label: s.destinationLabel,
            ),
          if (overflow)
            const NavigationDestination(
              icon: Icon(Icons.menu),
              label: 'More',
            ),
        ],
      ),
    );
  }
}
