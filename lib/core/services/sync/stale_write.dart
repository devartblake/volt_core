/// How far older than the stored time an incoming edit may be before the
/// server skips it. Mirrors `grace` in `public.reject_stale_update()`
/// (supabase/migrations/20261111120000_stale_write_guard.sql).
const Duration kStaleWriteGrace = Duration(minutes: 2);

/// Whether the database would skip an update as stale.
///
/// [incoming] is the client `updated_at` sent with the edit; [stored] is the
/// row's current `updated_at` (the server time of its last accepted change,
/// because `set_updated_at()` overwrites it). Documentation of the SQL rule,
/// used by tests; the real check runs in the trigger.
bool isStaleWrite({
  required DateTime incoming,
  required DateTime stored,
  Duration grace = kStaleWriteGrace,
}) =>
    incoming.isBefore(stored.subtract(grace));
