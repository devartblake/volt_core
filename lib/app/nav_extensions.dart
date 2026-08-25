import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers that don't throw when there is no page to go back to.
///
/// `context.pop()` throws `GoError: There is nothing to pop` whenever the
/// current route was reached by `go()` rather than `push()` — a `go` replaces
/// the stack, so nothing sits beneath it — or when the app was opened straight
/// onto that route by a deep link.
///
/// Both form pages hit this from their unsaved-changes guard. The drawer
/// navigates with `go`, which tears the form down; `PopScope`'s callback runs
/// during that teardown and awaits the discard dialog; by the time the
/// technician answers it, the location has already changed and the form's
/// route is gone. The log reads:
///
/// ```
/// [GoRouter] going to /settings
/// [GoRouter] popping /settings
/// GoError: There is nothing to pop
/// ```
///
/// Note the order — the `go` lands first. Popping there would not have undone
/// the form; it would have thrown the technician back off the page they had
/// just asked for.
extension SafeNavigation on BuildContext {
  /// Pop only if there is something to pop. Returns whether it popped.
  ///
  /// Use this when leaving is the *user's own* navigation and being unable to
  /// pop means they have already arrived somewhere else. Sending them anywhere
  /// in that case would override a choice they just made.
  bool popIfPossible() {
    final router = GoRouter.of(this);
    if (!router.canPop()) return false;
    router.pop();
    return true;
  }

  /// Pop, or go to [fallbackLocation] when there is nothing to pop.
  ///
  /// Use this when the code is finishing a task and the user must not be left
  /// on the page — after a save, say — so doing nothing is not an option.
  void popOrGo(String fallbackLocation) {
    if (!popIfPossible()) go(fallbackLocation);
  }
}
