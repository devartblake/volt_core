import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  group('apprentice role', () {
    test('label, wire value and parsing', () {
      expect(UserRole.apprentice.label, 'Apprentice');
      expect(UserRole.apprentice.wire, 'apprentice');
      expect(UserRoleX.fromString('apprentice'), UserRole.apprentice);
      expect(UserRoleX.fromString(' Apprentice '), UserRole.apprentice);
      expect(UserRoleX.fromString('technician'), UserRole.tech);
      expect(UserRoleX.fromString('tech'), UserRole.tech);
      expect(UserRoleX.fromString('nonsense'), isNull);
    });

    test('every role round-trips through its wire value', () {
      for (final role in UserRole.values) {
        expect(UserRoleX.fromString(role.wire), role);
      }
    });

    test('privilege ranks below technician', () {
      expect(UserRole.apprentice.privilege, 0);
      expect(UserRole.tech.privilege, 1);
      expect(UserRole.dispatcher.privilege, 2);
      expect(UserRole.supervisor.privilege, 3);
      expect(UserRole.admin.privilege, 4);
    });

    test('highestRole never prefers an apprentice over a technician', () {
      expect(highestRole({UserRole.apprentice, UserRole.tech}), UserRole.tech);
      expect(highestRole({UserRole.apprentice}), UserRole.apprentice);
      expect(highestRole({UserRole.apprentice, UserRole.admin}), UserRole.admin);
      expect(highestRole(<UserRole>[]), isNull);
    });

    test('only apprentices cannot sign off', () {
      expect(UserRole.apprentice.canSignOff, isFalse);
      for (final role in UserRole.values.where((r) => r != UserRole.apprentice)) {
        expect(role.canSignOff, isTrue, reason: role.name);
      }
    });

    test('apprentices and technicians are field workers; others are not', () {
      expect(UserRole.apprentice.isFieldWorker, isTrue);
      expect(UserRole.tech.isFieldWorker, isTrue);
      expect(UserRole.dispatcher.isFieldWorker, isFalse);
      expect(UserRole.supervisor.isFieldWorker, isFalse);
      expect(UserRole.admin.isFieldWorker, isFalse);
    });

    test('the blocked message is the agreed sentence', () {
      expect(kApprenticeSignOffMessage,
          'A technician or supervisor needs to sign this off.');
    });
  });
}
