import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/session_roles.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  test('offline keeps the role confirmed at the last sign-in', () {
    final r = resolveSessionRoles(granted: null, cached: UserRole.admin);
    expect(r.current, UserRole.admin);
    expect(r.granted, {UserRole.admin});
  });

  test('offline with nothing cached falls back to the preferred, then tech', () {
    expect(
      resolveSessionRoles(granted: null, preferred: UserRole.dispatcher).current,
      UserRole.dispatcher,
    );
    expect(resolveSessionRoles(granted: null).current, UserRole.tech);
  });

  test('online, the preferred role is used only when it is granted', () {
    final r = resolveSessionRoles(
      granted: {UserRole.tech, UserRole.supervisor},
      preferred: UserRole.supervisor,
    );
    expect(r.current, UserRole.supervisor);

    final other = resolveSessionRoles(
      granted: {UserRole.tech},
      preferred: UserRole.admin,
    );
    expect(other.current, UserRole.tech);
    expect(other.granted, {UserRole.tech});
  });

  test('online with several grants and no preference picks the highest', () {
    final r = resolveSessionRoles(
        granted: {UserRole.tech, UserRole.admin, UserRole.dispatcher});
    expect(r.current, UserRole.admin);
  });

  test('a user with no membership is a technician with nothing to switch to',
      () {
    final r = resolveSessionRoles(granted: <UserRole>{}, preferred: UserRole.admin);
    expect(r.current, UserRole.tech);
    expect(r.granted, isEmpty);
  });

  test('no membership but a provisioned role is honoured', () {
    final r = resolveSessionRoles(granted: <UserRole>{}, claimed: UserRole.supervisor);
    expect(r.current, UserRole.supervisor);
    expect(r.granted, {UserRole.supervisor});
  });
}
