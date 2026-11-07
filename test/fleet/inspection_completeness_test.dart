import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/photos/photo_attachment.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_maintenance_check.dart';

Map<String, CheckStatus> _allOk(InspectionCadence c) => {
      for (final item in inspectionItemsFor(c)) item.key: CheckStatus.ok,
    };

List<String> _gaps({
  InspectionCadence cadence = InspectionCadence.daily,
  Map<String, CheckStatus>? results,
  Map<String, String> notes = const {},
  Set<InspectionPhotoSlot>? photos,
  String driver = 'Sam Driver',
  String dispatcher = 'Dana Dispatch',
  bool driverSig = true,
  bool dispatcherSig = true,
  bool odometer = true,
}) =>
    inspectionGaps(
      cadence: cadence,
      results: results ?? _allOk(cadence),
      itemNotes: notes,
      photoSlots: photos ?? InspectionPhotoSlot.values.toSet(),
      driverName: driver,
      dispatcherName: dispatcher,
      hasDriverSignature: driverSig,
      hasDispatcherSignature: dispatcherSig,
      hasOdometer: odometer,
    );

void main() {
  group('inspectionGaps', () {
    test('a fully completed inspection has nothing missing', () {
      for (final c in InspectionCadence.values) {
        expect(_gaps(cadence: c), isEmpty, reason: c.name);
      }
    });

    test('a blank draft is missing everything, and says so', () {
      final gaps = _gaps(
        results: {},
        photos: {},
        driver: '',
        dispatcher: '',
        driverSig: false,
        dispatcherSig: false,
        odometer: false,
      );
      expect(gaps, contains('Odometer reading'));
      expect(gaps.where((g) => g.startsWith('Answer:')), isNotEmpty);
      expect(gaps, contains('Photo: Front of the vehicle'));
      expect(gaps, contains('Photo: Back of the vehicle'));
      expect(gaps, contains('Photo: Driver side of the vehicle'));
      expect(gaps, contains('Photo: Passenger side of the vehicle'));
      expect(gaps, contains("Assigned person's name"));
      expect(gaps, contains("Assigned person's signature"));
      expect(gaps, contains("Dispatcher's name"));
      expect(gaps, contains("Dispatcher's signature"));
    });

    test('one unanswered question is named', () {
      final results = _allOk(InspectionCadence.daily)..remove('brakes');
      final gaps = _gaps(results: results);
      expect(gaps, ['Answer: Brakes - pedal feel and parking brake']);
    });

    test('many unanswered questions are summarised after the first few', () {
      final gaps = _gaps(results: {});
      expect(gaps.where((g) => g.startsWith('Answer:')).length, 6);
      expect(gaps.any((g) => g.startsWith('...and ')), isTrue);
    });

    test('each missing photo is named separately', () {
      final gaps = _gaps(photos: {
        InspectionPhotoSlot.front,
        InspectionPhotoSlot.back,
      });
      expect(gaps, [
        'Photo: Driver side of the vehicle',
        'Photo: Passenger side of the vehicle',
      ]);
    });

    test('a flagged item needs an explanation', () {
      final results = _allOk(InspectionCadence.daily)
        ..['tires'] = CheckStatus.fail;
      expect(_gaps(results: results), [
        'Explain what is wrong: Tires - no flats, damage or low pressure',
      ]);
      expect(
        _gaps(results: results, notes: {'tires': 'Flat rear left'}),
        isEmpty,
      );
    });

    test('a blank-only explanation does not count', () {
      final results = _allOk(InspectionCadence.daily)
        ..['tires'] = CheckStatus.attention;
      expect(_gaps(results: results, notes: {'tires': '   '}), isNotEmpty);
    });

    test('both signatures and names are required, independently', () {
      expect(_gaps(driverSig: false), ["Assigned person's signature"]);
      expect(_gaps(dispatcherSig: false), ["Dispatcher's signature"]);
      expect(_gaps(driver: '  '), ["Assigned person's name"]);
      expect(_gaps(dispatcher: ''), ["Dispatcher's name"]);
    });

    test('weekly and monthly need the photos and signatures too', () {
      for (final c in [InspectionCadence.weekly, InspectionCadence.monthly]) {
        expect(_gaps(cadence: c, photos: {}), hasLength(4), reason: c.name);
        expect(
          _gaps(cadence: c, driverSig: false, dispatcherSig: false),
          hasLength(2),
          reason: c.name,
        );
      }
    });
  });

  group('daily status', () {
    VehicleInspection on(InspectionCadence c, DateTime at) =>
        VehicleInspection.newDraft(vehicleId: 'v1', cadence: c)
            .copyWith(inspectedAt: at);

    final noon = DateTime(2026, 11, 4, 12);

    test('done earlier today is ok; yesterday is overdue', () {
      expect(
        InspectionStatus.compute(
          InspectionCadence.daily,
          [on(InspectionCadence.daily, DateTime(2026, 11, 4, 6))],
          now: noon,
        ).state,
        InspectionDueState.ok,
      );
      expect(
        InspectionStatus.compute(
          InspectionCadence.daily,
          [on(InspectionCadence.daily, DateTime(2026, 11, 3, 23, 59))],
          now: noon,
        ).state,
        InspectionDueState.overdue,
      );
    });

    test('a weekly or monthly done today also covers the daily', () {
      for (final c in [InspectionCadence.weekly, InspectionCadence.monthly]) {
        expect(
          InspectionStatus.compute(
            InspectionCadence.daily,
            [on(c, DateTime(2026, 11, 4, 7))],
            now: noon,
          ).state,
          InspectionDueState.ok,
          reason: c.name,
        );
      }
    });

    test('a daily does not cover the weekly', () {
      expect(
        InspectionStatus.compute(
          InspectionCadence.weekly,
          [on(InspectionCadence.daily, DateTime(2026, 11, 4, 7))],
          now: noon,
        ).state,
        InspectionDueState.never,
      );
    });
  });

  group('VehicleInspection', () {
    test('a new draft has no answers pre-filled', () {
      final draft = VehicleInspection.newDraft(
        vehicleId: 'v1',
        cadence: InspectionCadence.daily,
      );
      expect(draft.results, isEmpty);
      expect(draft.isSigned, isFalse);
    });

    test('names, signatures and sign time survive JSON', () {
      final signed = VehicleInspection.newDraft(
        vehicleId: 'v1',
        cadence: InspectionCadence.daily,
      ).copyWith(
        driverName: 'Sam Driver',
        driverSignaturePath: '/sig/driver.png',
        dispatcherName: 'Dana Dispatch',
        dispatcherSignaturePath: '/sig/dispatcher.png',
        signedAt: DateTime(2026, 11, 4, 8),
      );
      final back = VehicleInspection.fromJson(signed.toJson());
      expect(back.driverName, 'Sam Driver');
      expect(back.dispatcherName, 'Dana Dispatch');
      expect(back.driverSignaturePath, '/sig/driver.png');
      expect(back.signedAt, DateTime(2026, 11, 4, 8));
      expect(back.isSigned, isTrue);
    });

    test('a record saved before signatures existed still loads', () {
      final old = VehicleInspection.fromJson(
        '{"id":"a","vehicleId":"v1","cadence":"weekly",'
        '"inspectedAt":"2026-10-01T00:00:00.000",'
        '"createdAt":"2026-10-01T00:00:00.000"}',
      );
      expect(old.isSigned, isFalse);
      expect(old.driverName, '');
    });
  });

  group('photo slots', () {
    test('keys are stable and round-trip', () {
      for (final slot in InspectionPhotoSlot.values) {
        expect(InspectionPhotoSlotX.fromKey(slot.key), slot);
      }
      expect(InspectionPhotoSlot.driverSide.key, 'driver_side');
      expect(InspectionPhotoSlotX.fromKey('nope'), isNull);
    });

    test('a photo remembers which slot it fills', () {
      final photo = PhotoAttachment.fromJson(PhotoAttachment(
        id: 'p',
        ownerType: PhotoAttachment.ownerVehicleInspection,
        ownerId: 'i',
        localPath: '/x.jpg',
        slot: InspectionPhotoSlot.front.key,
      ).toJson());
      expect(photo.slot, 'front');
      expect(
        PhotoAttachment.fromMap({'id': 'q', 'localPath': '/y.jpg'}).slot,
        isEmpty,
      );
    });
  });
}
