import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// One place that asks the OS for a runtime permission.
///
/// Declaring a permission in the manifest is only half of it. Android has
/// asked for dangerous permissions at runtime since 6.0, and the two halves
/// have to agree — the traps below are all cases where they did not.
class AppPermissions {
  const AppPermissions._();

  /// Ask for the camera before an `ImageSource.camera` capture.
  ///
  /// **This is not optional now that the manifest declares CAMERA.**
  /// `ACTION_IMAGE_CAPTURE`, which image_picker uses, works *without* the
  /// permission declared — the camera app takes the photo and hands it back.
  /// But once an app declares CAMERA, Android requires the runtime grant too,
  /// and the capture fails with a SecurityException instead. Adding the
  /// manifest line without this call would have broken a working feature.
  ///
  /// Returns false when the technician declined, so the caller can say so
  /// rather than showing an empty picker.
  static Future<bool> ensureCamera() async {
    // Desktop and web have no runtime camera permission; asking returns
    // denied on some of them, which would block a working picker.
    if (!_isMobile) return true;
    return _request(Permission.camera);
  }

  /// Ask for whatever this Android version calls "read the photo library".
  ///
  /// Android 13 replaced READ_EXTERNAL_STORAGE with per-type media reads, so
  /// `Permission.storage` is permanently denied there and `Permission.photos`
  /// (READ_MEDIA_IMAGES) is the live one. Below 13 it is the other way round.
  /// Rather than reading the SDK level — which would mean another package —
  /// ask for both and accept either, since exactly one is real on any given
  /// device.
  static Future<bool> ensurePhotoLibrary() async {
    if (!_isMobile) return true;
    if (await _request(Permission.photos)) return true;
    return _request(Permission.storage);
  }

  /// Ask for location.
  ///
  /// ⚠️ Nothing calls this yet, and nothing should until a location feature
  /// exists: there is no geolocator/location package in pubspec.yaml, so a
  /// granted permission still yields no position. Prompting for it now would
  /// be a scary dialog in exchange for nothing.
  static Future<bool> ensureLocation() async {
    if (!_isMobile) return true;
    return _request(Permission.locationWhenInUse);
  }

  /// True on the platforms that actually gate these at runtime.
  static bool get _isMobile {
    // Guarded because Platform throws on web.
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<bool> _request(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) return true;

      // permanentlyDenied means the OS will not show a dialog again; asking
      // returns the same answer instantly and the caller must send the user to
      // settings. Say so rather than looking like a silent failure.
      if (status.isPermanentlyDenied) {
        if (kDebugMode) {
          debugPrint(
            '[Permissions] ${permission.toString()} is permanently denied. '
            'The OS will not prompt again — openAppSettings() is the only way '
            'back.',
          );
        }
        return false;
      }

      final result = await permission.request();
      return result.isGranted || result.isLimited;
    } catch (error) {
      // A missing platform implementation (desktop, an unconfigured iOS pod)
      // throws rather than returning denied. Failing open here keeps a working
      // feature working; the underlying call fails with its own error if the
      // permission really was required.
      if (kDebugMode) {
        debugPrint('[Permissions] ${permission.toString()} check failed: $error');
      }
      return true;
    }
  }

  /// Open the OS settings page for this app, for the permanently-denied case.
  static Future<bool> openSettings() => openAppSettings();
}
