import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';

void main() {
  group('highestRole', () {
    test('picks the most privileged grant', () {
      expect(
        highestRole({UserRole.tech, UserRole.admin, UserRole.dispatcher}),
        UserRole.admin,
      );
      expect(
        highestRole({UserRole.tech, UserRole.dispatcher}),
        UserRole.dispatcher,
      );
      expect(highestRole({UserRole.tech}), UserRole.tech);
    });

    test('returns null for no grants', () {
      expect(highestRole(const <UserRole>{}), isNull);
    });

    test('privilege ordering is strict tech < dispatcher < supervisor < admin',
        () {
      expect(UserRole.tech.privilege, lessThan(UserRole.dispatcher.privilege));
      expect(
        UserRole.dispatcher.privilege,
        lessThan(UserRole.supervisor.privilege),
      );
      expect(
        UserRole.supervisor.privilege,
        lessThan(UserRole.admin.privilege),
      );
    });
  });

  group('AuthState.canActAs', () {
    const state = AuthState(
      isAuthenticated: true,
      currentRole: UserRole.tech,
      userId: 'u1',
      grantedRoles: {UserRole.tech, UserRole.dispatcher},
    );

    test('accepts a granted role', () {
      expect(state.canActAs(UserRole.tech), isTrue);
      expect(state.canActAs(UserRole.dispatcher), isTrue);
    });

    test('refuses a role the server did not grant', () {
      expect(state.canActAs(UserRole.admin), isFalse);
      expect(state.canActAs(UserRole.supervisor), isFalse);
    });

    test('unauthenticated state grants nothing', () {
      const anon = AuthState.unauthenticated();
      for (final role in UserRole.values) {
        expect(anon.canActAs(role), isFalse);
      }
    });

    test('copyWith preserves grants when not overridden', () {
      final switched = state.copyWith(currentRole: UserRole.dispatcher);
      expect(switched.grantedRoles, state.grantedRoles);
      expect(switched.currentRole, UserRole.dispatcher);
    });
  });

  group('UserRoleX.fromString', () {
    test('parses server role strings', () {
      expect(UserRoleX.fromString('admin'), UserRole.admin);
      expect(UserRoleX.fromString('technician'), UserRole.tech);
      expect(UserRoleX.fromString('Supervisor'), UserRole.supervisor);
      expect(UserRoleX.fromString(' dispatcher '), UserRole.dispatcher);
    });

    test('returns null for unknown or empty values', () {
      expect(UserRoleX.fromString('owner'), isNull);
      expect(UserRoleX.fromString(''), isNull);
      expect(UserRoleX.fromString(null), isNull);
    });
  });
}
