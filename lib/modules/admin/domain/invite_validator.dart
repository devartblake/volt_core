import '../../auth/domain/user_role.dart';

/// Client-side mirror of `supabase/functions/invite-user/validate.ts`.
///
/// Keep the two in step: the function is the authority, this only saves a
/// round trip and lets the form point at the exact field.
class InviteValidator {
  const InviteValidator._();

  static const int maxEmail = 254;
  static const int maxName = 80;
  static const int maxPhone = 30;

  static final RegExp _email =
      RegExp(r'^[^\s@,;<>()"]+@[^\s@,;<>()"]+\.[^\s@,;<>()"]+$');
  static final RegExp _phone = RegExp(r'^[0-9+\-() ]+$');

  /// Lowercased, trimmed form that is sent to the server.
  static String normalizeEmail(String? value) => (value ?? '').trim().toLowerCase();

  static String? email(String? value) {
    final e = normalizeEmail(value);
    if (e.isEmpty) return 'Enter an email address.';
    if (e.length > maxEmail || !_email.hasMatch(e)) {
      return 'Enter a valid email address.';
    }
    final domain = e.substring(e.indexOf('@') + 1);
    if (domain.startsWith('.') || domain.endsWith('.') || domain.contains('..')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? name(String? value) {
    final n = (value ?? '').trim();
    if (n.isEmpty) return 'Enter a name.';
    if (n.length > maxName) return 'Name must be $maxName characters or fewer.';
    return null;
  }

  /// Phone is optional.
  static String? phone(String? value) {
    final p = (value ?? '').trim();
    if (p.isEmpty) return null;
    if (p.length > maxPhone ||
        !_phone.hasMatch(p) ||
        !RegExp(r'[0-9]').hasMatch(p)) {
      return 'Use digits, spaces and + - ( ) only.';
    }
    return null;
  }

  static String? role(UserRole? value) =>
      value == null ? 'Choose a role.' : null;
}
