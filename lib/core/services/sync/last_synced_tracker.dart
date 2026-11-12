/// Remembers the last fully successful sync across app launches.
///
/// Storage is injected so the rule can be tested without Hive.
class LastSyncedTracker {
  LastSyncedTracker({
    required DateTime? Function() read,
    required Future<void> Function(DateTime value) write,
    DateTime Function()? now,
  })  : _read = read,
        _write = write,
        _now = now ?? DateTime.now;

  final DateTime? Function() _read;
  final Future<void> Function(DateTime value) _write;
  final DateTime Function() _now;

  DateTime? _value;

  /// Last successful sync time, or null if there has never been one.
  DateTime? get value => _value;

  /// Load the persisted value (call once on start).
  DateTime? load() => _value = _read();

  /// Record the outcome of a drain. Only a run with zero failures stamps the
  /// time; a partly failed run leaves the previous value alone.
  Future<void> recordRun({required int failed}) async {
    if (failed != 0) return;
    final t = _now();
    _value = t;
    try {
      await _write(t);
    } catch (_) {
      // Persistence is best-effort; the in-memory value is still correct.
    }
  }
}
