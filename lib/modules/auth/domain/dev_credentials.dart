import 'user_role.dart';

/// Credentials for the developer "one-tap" sign-in on the login page.
///
/// They are **never stored in the source tree**. They are compile-time values
/// supplied when the app is built or run, from a git-ignored file:
///
/// ```
/// flutter run --dart-define-from-file=dev_credentials.local.json
/// ```
///
/// (see `dev_credentials.example.json` for the keys). A value that is not
/// supplied is simply empty, in which case the dev button falls back to the
/// local-only bypass.
///
/// One account is enough: `VOLTCORE_DEV_EMAIL` / `VOLTCORE_DEV_PASSWORD`. To
/// test the different roles, also give a pair per role
/// (`VOLTCORE_DEV_EMAIL_ADMIN` / `VOLTCORE_DEV_PASSWORD_ADMIN`, and the same for
/// `_SUPERVISOR`, `_DISPATCHER`, `_TECH`, `_APPRENTICE`); the role picked on the login page
/// then signs in with that role's own account.
///
/// Because these are baked into the build, use them for debug builds only and
/// never distribute an app built with them. The sign-in itself is still gated
/// by `FeatureFlags.devLoginBypassEnabled`, which is off in release builds.
class DevCredentials {
  const DevCredentials(this.email, this.password);

  final String email;
  final String password;

  static const _email = String.fromEnvironment('VOLTCORE_DEV_EMAIL');
  static const _password = String.fromEnvironment('VOLTCORE_DEV_PASSWORD');

  static const _emailAdmin = String.fromEnvironment('VOLTCORE_DEV_EMAIL_ADMIN');
  static const _passwordAdmin =
      String.fromEnvironment('VOLTCORE_DEV_PASSWORD_ADMIN');
  static const _emailSupervisor =
      String.fromEnvironment('VOLTCORE_DEV_EMAIL_SUPERVISOR');
  static const _passwordSupervisor =
      String.fromEnvironment('VOLTCORE_DEV_PASSWORD_SUPERVISOR');
  static const _emailDispatcher =
      String.fromEnvironment('VOLTCORE_DEV_EMAIL_DISPATCHER');
  static const _passwordDispatcher =
      String.fromEnvironment('VOLTCORE_DEV_PASSWORD_DISPATCHER');
  static const _emailTech = String.fromEnvironment('VOLTCORE_DEV_EMAIL_TECH');
  static const _passwordTech =
      String.fromEnvironment('VOLTCORE_DEV_PASSWORD_TECH');
  static const _emailApprentice =
      String.fromEnvironment('VOLTCORE_DEV_EMAIL_APPRENTICE');
  static const _passwordApprentice =
      String.fromEnvironment('VOLTCORE_DEV_PASSWORD_APPRENTICE');

  /// The account to sign in with for [role], or null when none is configured.
  static DevCredentials? forRole(UserRole role) => resolve(
        role,
        email: _email,
        password: _password,
        roleEmail: switch (role) {
          UserRole.admin => _emailAdmin,
          UserRole.supervisor => _emailSupervisor,
          UserRole.dispatcher => _emailDispatcher,
          UserRole.tech => _emailTech,
          UserRole.apprentice => _emailApprentice,
        },
        rolePassword: switch (role) {
          UserRole.admin => _passwordAdmin,
          UserRole.supervisor => _passwordSupervisor,
          UserRole.dispatcher => _passwordDispatcher,
          UserRole.tech => _passwordTech,
          UserRole.apprentice => _passwordApprentice,
        },
      );

  /// The selection rule, on plain strings so it can be tested without
  /// compile-time defines. A role's own account is used only when both its
  /// email and password are present; otherwise the shared pair, and failing
  /// that null.
  static DevCredentials? resolve(
    UserRole role, {
    required String email,
    required String password,
    required String roleEmail,
    required String rolePassword,
  }) {
    if (roleEmail.isNotEmpty && rolePassword.isNotEmpty) {
      return DevCredentials(roleEmail, rolePassword);
    }
    if (email.isNotEmpty && password.isNotEmpty) {
      return DevCredentials(email, password);
    }
    return null;
  }

  /// Never prints the password, so a stray log line cannot leak it.
  @override
  String toString() => 'DevCredentials($email, ***)';
}
