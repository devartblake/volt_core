import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';

void main() {
  VehicleEntity draft() => VehicleEntity.newDraft(tenantId: 'tenant-1');

  group('VIN validation', () {
    test('accepts a well-formed VIN', () {
      expect(validateVin('1FTNR1ZM7FKB20115'), isNull);
    });

    test('accepts blank — a vehicle is added before anyone reads the VIN', () {
      // Refusing to save until somebody walks out to the lot would push the
      // record onto a sticky note, which is what this replaces.
      expect(validateVin(null), isNull);
      expect(validateVin(''), isNull);
      expect(validateVin('   '), isNull);
    });

    test('rejects the wrong length and says what it counted', () {
      final problem = validateVin('1FTNR1ZM7FKB201');
      expect(problem, contains('17 characters'));
      expect(problem, contains('15'));
    });

    test('rejects I, O and Q', () {
      // Excluded from the VIN alphabet by standard precisely because they are
      // misread as 1 and 0 — the failure mode when copying one off a doorframe.
      for (final bad in ['I', 'O', 'Q']) {
        final vin = '${bad}FTNR1ZM7FKB20115'.substring(0, 17);
        expect(validateVin(vin), isNotNull, reason: 'should reject "$bad"');
      }
    });

    test('normalises case, spaces and dashes before judging', () {
      expect(validateVin('1ftnr1zm7fkb20115'), isNull);
      expect(validateVin(' 1FTNR1ZM7-FKB20115 '.replaceAll('-', '')), isNull);
      expect(normalizeVin(' 1ftnr1zm7-fkb20115 '.trim()), '1FTNR1ZM7FKB20115');
    });
  });

  group('wire values', () {
    test('two-word statuses use an underscore, not the enum name', () {
      // The check constraint spells them with an underscore and rejects
      // `outOfService`. Same trap as UserRoleX.wire.
      expect(VehicleStatus.outOfService.name, 'outOfService');
      expect(VehicleStatus.outOfService.wire, 'out_of_service');
    });

    test('every status wire value round-trips', () {
      for (final status in VehicleStatus.values) {
        expect(VehicleStatusX.fromWire(status.wire), status);
      }
    });

    test('every type wire value round-trips', () {
      for (final type in VehicleType.values) {
        expect(VehicleTypeX.fromWire(type.wire), type);
      }
    });

    test('an unknown wire value degrades instead of throwing', () {
      // A row written by a newer build must not crash an older one.
      expect(VehicleStatusX.fromWire('teleported'), VehicleStatus.active);
      expect(VehicleTypeX.fromWire('hovercraft'), VehicleType.other);
      expect(VehicleStatusX.fromWire(null), VehicleStatus.active);
    });
  });

  group('displayTitle', () {
    test('prefers the designation — it is what the crew calls it', () {
      final vehicle =
          draft().copyWith(designation: 'Truck A', make: 'Ford', model: 'Transit');
      expect(vehicle.displayTitle, 'Truck A');
    });

    test('falls back so a half-filled record is still distinguishable', () {
      expect(
        draft().copyWith(make: 'Ford', model: 'Transit').displayTitle,
        'Ford Transit',
      );
      expect(draft().copyWith(licensePlate: 'ABC-1234').displayTitle, 'ABC-1234');
      expect(draft().displayTitle, 'Unnamed vehicle');
    });
  });

  group('assignment', () {
    test('clearAssignee actually clears it', () {
      // A plain `copyWith(assignedToUserId: null)` cannot distinguish "leave it
      // alone" from "unassign", which is why the explicit flag exists. Getting
      // this wrong would leave a vehicle visible to a technician who no longer
      // drives it.
      final assigned = draft().copyWith(assignedToUserId: 'user-9');
      expect(assigned.isAssigned, isTrue);

      expect(assigned.copyWith().assignedToUserId, 'user-9');
      expect(assigned.copyWith(clearAssignee: true).assignedToUserId, isNull);
      expect(assigned.copyWith(clearAssignee: true).isAssigned, isFalse);
    });

    test('clearVin and clearModelYear behave the same way', () {
      final full = draft().copyWith(vin: '1FTNR1ZM7FKB20115', modelYear: 2021);
      expect(full.copyWith().vin, '1FTNR1ZM7FKB20115');
      expect(full.copyWith(clearVin: true).vin, isNull);
      expect(full.copyWith(clearModelYear: true).modelYear, isNull);
    });
  });

  test('only an active vehicle is dispatchable', () {
    expect(VehicleStatus.active.isDispatchable, isTrue);
    expect(VehicleStatus.maintenance.isDispatchable, isFalse);
    expect(VehicleStatus.outOfService.isDispatchable, isFalse);
    expect(VehicleStatus.retired.isDispatchable, isFalse);
  });
}
