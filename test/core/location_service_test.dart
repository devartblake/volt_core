import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:voltcore/core/services/location/location_service.dart';
import 'package:voltcore/core/services/location/site_check_in.dart';

Position _positionAt(double latitude, double longitude, {double accuracy = 8}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 9, 16),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  final service = LocationService.instance;

  Future<CheckInResult> capture({
    bool serviceEnabled = true,
    bool permitted = true,
    Future<Position> Function()? readPosition,
  }) {
    return service.capture(
      isServiceEnabled: () async => serviceEnabled,
      checkPermission: () async => permitted,
      readPosition: readPosition ?? () async => _positionAt(40.7061, -73.9369),
    );
  }

  group('capture', () {
    test('returns a check-in on a good fix', () async {
      final result = await capture();

      expect(result, isA<CheckInCaptured>());
      final checkIn = (result as CheckInCaptured).checkIn;
      expect(checkIn.latitude, 40.7061);
      expect(checkIn.longitude, -73.9369);
      expect(checkIn.accuracyMeters, 8);
      expect(checkIn.quality, SiteCheckInQuality.good);
    });

    test('checks the device service BEFORE asking for permission', () async {
      // Order matters: granting permission while location is off device-wide
      // yields a grant that still produces nothing, and the technician is left
      // thinking they fixed it.
      var askedPermission = false;

      final result = await service.capture(
        isServiceEnabled: () async => false,
        checkPermission: () async {
          askedPermission = true;
          return true;
        },
        readPosition: () async => _positionAt(40.7061, -73.9369),
      );

      expect(result, isA<CheckInFailed>());
      expect((result as CheckInFailed).failure, CheckInFailure.serviceDisabled);
      expect(askedPermission, isFalse,
          reason: 'must not prompt while location is off device-wide');
    });

    test('reports a declined permission distinctly', () async {
      final result = await capture(permitted: false);

      expect(
        (result as CheckInFailed).failure,
        CheckInFailure.permissionDenied,
      );
    });

    test('reports a timeout as its own failure', () async {
      // The basement case, and the one where the advice differs: "step
      // outside", not "something went wrong". geolocator's timeLimit throws
      // dart:async's TimeoutException, so that is what is thrown here — a
      // locally declared look-alike would silently fall through to
      // `unavailable` and give the wrong advice.
      final result = await capture(
        readPosition: () async => throw TimeoutException('no fix'),
      );

      expect((result as CheckInFailed).failure, CheckInFailure.timedOut);
    });

    test('a platform error degrades to unavailable rather than throwing',
        () async {
      final result = await capture(
        readPosition: () async => throw const LocationServiceDisabledException(),
      );

      expect(result, isA<CheckInFailed>());
      expect((result as CheckInFailed).failure, CheckInFailure.unavailable);
    });

    test('refuses a (0, 0) fix', () async {
      // Some devices return Null Island for a failed read. Storing it would
      // put every inspection in the Gulf of Guinea.
      final result = await capture(readPosition: () async => _positionAt(0, 0));

      expect((result as CheckInFailed).failure, CheckInFailure.unavailable);
    });

    test('keeps a poor fix but marks it weak', () async {
      // A cell-tower fix is still worth recording; it just is not evidence of
      // standing in the plant room, and the UI says so.
      final result = await capture(
        readPosition: () async =>
            _positionAt(40.7061, -73.9369, accuracy: 1200),
      );

      final checkIn = (result as CheckInCaptured).checkIn;
      expect(checkIn.quality, SiteCheckInQuality.poor);
      expect(checkIn.quality.isWeak, isTrue);
    });
  });

  group('failure messages', () {
    test('each says what to do next', () {
      // "Location failed" when the answer is "turn on GPS" wastes a trip to
      // the office.
      expect(CheckInFailure.serviceDisabled.message, contains('Settings'));
      expect(CheckInFailure.timedOut.message, contains('outside'));
      expect(CheckInFailure.permissionDenied.message, contains('Settings'));
      expect(CheckInFailure.unavailable.message, isNotEmpty);
    });

    test('only the permission failure offers app settings', () {
      // GPS being off device-wide is not fixed on the app's settings page, so
      // offering that button would send the technician somewhere useless.
      expect(CheckInFailure.permissionDenied.opensAppSettings, isTrue);
      expect(CheckInFailure.serviceDisabled.opensAppSettings, isFalse);
      expect(CheckInFailure.timedOut.opensAppSettings, isFalse);
      expect(CheckInFailure.unavailable.opensAppSettings, isFalse);
    });
  });
}
