import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/invite_validator.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  group('email', () {
    test('accepts and normalises', () {
      expect(InviteValidator.email('  Ann@Example.COM '), isNull);
      expect(InviteValidator.normalizeEmail('  Ann@Example.COM '),
          'ann@example.com');
    });

    test('rejects bad shapes', () {
      for (final e in [
        '',
        '   ',
        null,
        'nope',
        'a@b',
        'a b@c.com',
        'a@b..com',
        'a@.com',
        'a@b.com.',
        'a@@b.com',
        'a,b@c.com',
        '${'a' * 250}@b.com',
      ]) {
        expect(InviteValidator.email(e), isNotNull, reason: '$e');
      }
    });
  });

  group('name', () {
    test('1 to 80 characters after trimming', () {
      expect(InviteValidator.name(''), isNotNull);
      expect(InviteValidator.name('   '), isNotNull);
      expect(InviteValidator.name(null), isNotNull);
      expect(InviteValidator.name('A'), isNull);
      expect(InviteValidator.name('  ${'x' * 80}  '), isNull);
      expect(InviteValidator.name('x' * 81), contains('80'));
    });
  });

  group('phone', () {
    test('optional', () {
      expect(InviteValidator.phone(null), isNull);
      expect(InviteValidator.phone('  '), isNull);
    });

    test('allows digits + - ( ) and spaces only', () {
      expect(InviteValidator.phone('+1 (555) 123-4567'), isNull);
      expect(InviteValidator.phone('555-abc'), isNotNull);
      expect(InviteValidator.phone('555;1'), isNotNull);
      expect(InviteValidator.phone('+-()'), isNotNull);
      expect(InviteValidator.phone('1' * 31), isNotNull);
    });
  });

  test('role is required', () {
    expect(InviteValidator.role(null), isNotNull);
    expect(InviteValidator.role(UserRole.admin), isNull);
  });
}
