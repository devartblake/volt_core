import 'package:flutter_riverpod/legacy.dart';

import '../core/services/settings/app_preferences_service.dart';

/// Where navigation sits on tablets (windows at least 800 wide).
///
/// Phones always get the drawer plus a bottom bar; this only chooses between
/// the side rail (default) and a bottom bar on larger screens.
enum NavStyle {
  /// Labelled rail down the left edge.
  rail,

  /// The same destinations as a bottom bar, nearer the thumbs when the tablet
  /// is held in portrait.
  bottom;

  static NavStyle decode(String value) =>
      value == 'bottom' ? NavStyle.bottom : NavStyle.rail;
}

class NavStyleController extends StateNotifier<NavStyle> {
  NavStyleController(this._preferences)
      : super(NavStyle.decode(_preferences.navStyle));

  final AppPreferencesService _preferences;

  Future<void> setStyle(NavStyle style) async {
    state = style;
    await _preferences.setNavStyle(style.name);
  }
}

final navStyleProvider = StateNotifierProvider<NavStyleController, NavStyle>(
  (ref) => NavStyleController(AppPreferencesService.instance),
);
