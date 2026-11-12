import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../permissions/app_permissions.dart';
import 'site_check_in.dart';

/// Why a check-in did not produce a position.
///
/// Four distinct failures, because each one has a different fix and telling a
/// technician "location failed" when the answer is "turn on GPS" wastes a trip
/// to the office.
enum CheckInFailure {
  /// Location services are switched off for the whole device.
  serviceDisabled,

  /// The technician declined, or the OS will not ask again.
  permissionDenied,

  /// No fix within the time budget — common inside a basement generator room,
  /// which is exactly where this app gets used.
  timedOut,

  /// The platform returned something unusable.
  unavailable,
}

extension CheckInFailureX on CheckInFailure {
  /// What to tell the technician, phrased as the next action.
  String get message => switch (this) {
        CheckInFailure.serviceDisabled =>
          'Location is switched off on this device. Turn it on in Settings, '
              'then check in again.',
        CheckInFailure.permissionDenied =>
          'This app does not have location access. Allow it in Settings to '
              'record where the work was done.',
        CheckInFailure.timedOut =>
          'No GPS fix — common indoors and in basements. Step outside or near '
              'a window and try again.',
        CheckInFailure.unavailable =>
          'Could not read a position from this device.',
      };

  /// Whether pointing the technician at app settings would help. GPS being off
  /// device-wide is not fixed there.
  bool get opensAppSettings => this == CheckInFailure.permissionDenied;
}

/// The outcome of a check-in attempt.
sealed class CheckInResult {
  const CheckInResult();

  const factory CheckInResult.captured(SiteCheckIn checkIn) = CheckInCaptured;
  const factory CheckInResult.failed(CheckInFailure failure) = CheckInFailed;
}

class CheckInCaptured extends CheckInResult {
  const CheckInCaptured(this.checkIn);
  final SiteCheckIn checkIn;
}

class CheckInFailed extends CheckInResult {
  const CheckInFailed(this.failure);
  final CheckInFailure failure;
}

/// Reads the device position for a site check-in.
///
/// One shot, on demand. Nothing here starts a position stream: the app records
/// where a form was filled in, and continuous tracking would be a different
/// feature needing a different conversation with the crew.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// How long to wait for a fix.
  ///
  /// Generous, because the typical site is a basement or a plant room where
  /// the first fix is slow. Not unbounded, because a technician holding a
  /// tablet up in a switchgear room needs to be told to step outside rather
  /// than left watching a spinner.
  static const Duration _timeout = Duration(seconds: 20);

  /// Capture the current position, asking for permission if needed.
  ///
  /// [checkPermission] and [readPosition] exist so tests can drive every branch
  /// without a device; production calls use the real ones.
  Future<CheckInResult> capture({
    Future<bool> Function()? isServiceEnabled,
    Future<bool> Function()? checkPermission,
    Future<Position> Function()? readPosition,
  }) async {
    final serviceCheck = isServiceEnabled ?? Geolocator.isLocationServiceEnabled;
    final permissionCheck = checkPermission ?? AppPermissions.ensureLocation;

    try {
      // Order matters. Asking for permission while location is off device-wide
      // gets a grant that still yields nothing, and the technician is left
      // thinking they fixed it.
      if (!await serviceCheck()) {
        return const CheckInResult.failed(CheckInFailure.serviceDisabled);
      }

      if (!await permissionCheck()) {
        return const CheckInResult.failed(CheckInFailure.permissionDenied);
      }

      final position = await (readPosition ?? _readPosition)();

      if (!SiteCheckIn.isPlausible(position.latitude, position.longitude)) {
        // A (0, 0) fix is what a failed read looks like on some devices.
        // Storing it would put every inspection in the Gulf of Guinea.
        return const CheckInResult.failed(CheckInFailure.unavailable);
      }

      return CheckInResult.captured(
        SiteCheckIn(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: DateTime.now().toUtc(),
        ),
      );
    } on TimeoutException catch (_) {
      // geolocator's `timeLimit` throws dart:async's TimeoutException, so this
      // must be that one and not a locally declared look-alike — the branch
      // would never fire and a technician in a basement would be told
      // "could not read a position" instead of "step outside".
      return const CheckInResult.failed(CheckInFailure.timedOut);
    } catch (error) {
      if (kDebugMode) debugPrint('[Location] capture failed: $error');
      // LocationServiceDisabledException and PermissionDefinitionsNotFound both
      // land here; the generic message is honest about not knowing which.
      return const CheckInResult.failed(CheckInFailure.unavailable);
    }
  }

  static Future<Position> _readPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _timeout,
      ),
    );
  }
}
