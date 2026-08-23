import 'package:hive/hive.dart';

/// A named handle to a Hive box that cannot go stale.
///
/// Caching a `Box` instance is a trap in this app. [HiveService.reset] — what
/// the debug menu's "clear data" runs, and what the sync-queue troubleshooting
/// advice tells people to use — closes every box and reopens them as *new*
/// instances. Any reference captured beforehand is dead, and every subsequent
/// use throws `HiveError: Box has already been closed` with nothing in the
/// message connecting it to the reset. The app keeps running and looks fine
/// until you touch a form.
///
/// A dozen services each held their own cached box, so one reset broke
/// selection options, maintenance, drafts, photos and the sync queue at once,
/// all of them until the app was restarted.
///
/// Resolving by name is a map lookup inside Hive, not I/O, so there was never
/// a reason to cache the instance.
class HiveBoxRef<T> {
  const HiveBoxRef(this.name);

  final String name;

  bool get isOpen => Hive.isBoxOpen(name);

  /// The open box.
  ///
  /// Throws if it was never opened, which is a wiring mistake rather than a
  /// runtime condition — the box should have been opened during startup.
  Box<T> get value => Hive.box<T>(name);

  /// The box, opening it first if it is not already open.
  Future<Box<T>> ensureOpen() async =>
      Hive.isBoxOpen(name) ? Hive.box<T>(name) : Hive.openBox<T>(name);
}
