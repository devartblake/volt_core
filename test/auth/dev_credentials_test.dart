import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/dev_credentials.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  DevCredentials? pick({
    String email = '',
    String password = '',
    String roleEmail = '',
    String rolePassword = '',
  }) =>
      DevCredentials.resolve(
        UserRole.admin,
        email: email,
        password: password,
        roleEmail: roleEmail,
        rolePassword: rolePassword,
      );

  test('nothing configured means no dev account (local-only fallback)', () {
    expect(pick(), isNull);
    expect(DevCredentials.forRole(UserRole.tech), isNull);
  });

  test('the shared account is used for any role', () {
    final c = pick(email: 'dev@example.com', password: 'pw');
    expect(c?.email, 'dev@example.com');
    expect(c?.password, 'pw');
  });

  test('a role-specific account wins over the shared one', () {
    final c = pick(
      email: 'dev@example.com',
      password: 'pw',
      roleEmail: 'admin@example.com',
      rolePassword: 'admin-pw',
    );
    expect(c?.email, 'admin@example.com');
  });

  test('half a pair is ignored: email without password is not usable', () {
    expect(pick(email: 'dev@example.com'), isNull);
    expect(pick(password: 'pw'), isNull);
    // A role email with no role password falls back to the shared pair.
    final c = pick(
      email: 'dev@example.com',
      password: 'pw',
      roleEmail: 'admin@example.com',
    );
    expect(c?.email, 'dev@example.com');
  });

  test('toString never reveals the password', () {
    final text = const DevCredentials('dev@example.com', 'super-secret').toString();
    expect(text, contains('dev@example.com'));
    expect(text, isNot(contains('super-secret')));
  });
}
