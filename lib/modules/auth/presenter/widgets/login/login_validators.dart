/// Pure validation for the login form, kept apart from widgets so it can be
/// unit tested.
class LoginValidators {
  const LoginValidators._();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) {
      return 'Enter a valid email address, like name@company.com.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  static bool isValid(String email, String password) =>
      LoginValidators.email(email) == null &&
      LoginValidators.password(password) == null;

  /// Turns a thrown error into a short message for the error banner.
  static String describeError(Object error) {
    var text = error.toString().trim();
    for (final prefix in const ['Exception: ', 'AuthException: ']) {
      if (text.startsWith(prefix)) text = text.substring(prefix.length);
    }
    if (text.isEmpty) return 'Sign in failed. Please try again.';
    return text;
  }
}
