import 'user_role.dart';

/// The role a session acts as, and every role it may switch to.
class SessionRoles {
  const SessionRoles(this.current, this.granted);

  final UserRole current;
  final Set<UserRole> granted;
}

/// Decides a session's roles from what the server said.
///
/// [granted] is `null` when the server could not be asked (offline, DNS
/// failure), which is different from an empty set (asked, and the user holds no
/// role). Treating "could not ask" as "has no role" used to demote a signed-in
/// admin to a technician the moment the tablet lost its connection, hiding
/// their screens until the next online sign-in.
///
/// When the server cannot be asked, the role from the last successful sign-in
/// ([cached]) is kept. That only affects what the app shows: the database still
/// enforces access on every request.
SessionRoles resolveSessionRoles({
  required Set<UserRole>? granted,
  UserRole? preferred,
  UserRole? claimed,
  UserRole? cached,
}) {
  if (granted == null) {
    // Offline: carry on as the role last confirmed by the server.
    final role = cached ?? preferred ?? claimed ?? UserRole.tech;
    return SessionRoles(role, {role});
  }

  if (granted.isEmpty) {
    // Asked, and no membership. The role the account was provisioned with
    // (app metadata) is honoured if there is one; otherwise lowest privilege
    // with nothing to switch to.
    if (claimed != null) return SessionRoles(claimed, {claimed});
    return const SessionRoles(UserRole.tech, {});
  }

  if (preferred != null && granted.contains(preferred)) {
    return SessionRoles(preferred, granted);
  }
  return SessionRoles(highestRole(granted) ?? UserRole.tech, granted);
}
