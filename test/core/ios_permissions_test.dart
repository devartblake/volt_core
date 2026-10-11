import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the iOS permission wiring, which has two failure modes and no
/// compiler or analyzer that catches either.
///
/// A macro without its `Info.plist` usage description is an App Store
/// rejection (ITMS-90683). A usage description without its macro is a
/// permission that silently reports `denied` on every device. Both build
/// green, and both are only discovered by a human with an iPhone.
void main() {
  final podfile = File('ios/Podfile');
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final permissions =
      File('lib/core/services/permissions/app_permissions.dart').readAsStringSync();

  /// The `NS*UsageDescription` each permission_handler macro requires, taken
  /// from the comments in permission_handler_apple's PermissionHandlerEnums.h.
  const requiredPlistKey = <String, String>{
    'PERMISSION_CAMERA': 'NSCameraUsageDescription',
    'PERMISSION_MICROPHONE': 'NSMicrophoneUsageDescription',
    'PERMISSION_PHOTOS': 'NSPhotoLibraryUsageDescription',
    'PERMISSION_PHOTOS_ADD_ONLY': 'NSPhotoLibraryAddUsageDescription',
    'PERMISSION_LOCATION': 'NSLocationWhenInUseUsageDescription',
    'PERMISSION_LOCATION_WHENINUSE': 'NSLocationWhenInUseUsageDescription',
    'PERMISSION_LOCATION_ALWAYS':
        'NSLocationAlwaysAndWhenInUseUsageDescription',
    'PERMISSION_EVENTS': 'NSCalendarsUsageDescription',
    'PERMISSION_REMINDERS': 'NSRemindersFullAccessUsageDescription',
    'PERMISSION_CONTACTS': 'NSContactsUsageDescription',
    'PERMISSION_SPEECH_RECOGNIZER': 'NSSpeechRecognitionUsageDescription',
    'PERMISSION_MEDIA_LIBRARY': 'NSAppleMusicUsageDescription',
    'PERMISSION_SENSORS': 'NSMotionUsageDescription',
    'PERMISSION_BLUETOOTH': 'NSBluetoothAlwaysUsageDescription',
    'PERMISSION_APP_TRACKING_TRANSPARENCY': 'NSUserTrackingUsageDescription',
  };

  /// Macros the Podfile turns on.
  Set<String> enabledMacros() {
    final source = podfile.readAsStringSync();
    return RegExp(r"'(PERMISSION_[A-Z_]+)=1'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
  }

  test('the Podfile exists at all', () {
    // Without it, `pod install` never runs the block below and every
    // permission_handler check returns denied on iOS.
    expect(podfile.existsSync(), isTrue);
  });

  test('every enabled macro has its usage description', () {
    // The ITMS-90683 direction: compiling in a permission API with no reason
    // string in Info.plist is a rejection, not a warning.
    for (final macro in enabledMacros()) {
      final key = requiredPlistKey[macro];
      expect(
        key,
        isNotNull,
        reason: '$macro is enabled but this test does not know which '
            'NS*UsageDescription it needs — add it to requiredPlistKey',
      );
      expect(
        infoPlist.contains(key!),
        isTrue,
        reason: '$macro is enabled but Info.plist has no $key. '
            'App Store review rejects this as ITMS-90683.',
      );
    }
  });

  test('every permission the app asks for is compiled in', () {
    // The other direction, and the quiet one: permission_handler_apple defines
    // each macro to 0 when the Podfile does not set it — its podspec supplies
    // no defaults — so an unlisted permission reports denied forever with a
    // perfectly green build.
    const macroFor = <String, String>{
      'Permission.camera': 'PERMISSION_CAMERA',
      'Permission.photos': 'PERMISSION_PHOTOS',
      'Permission.locationWhenInUse': 'PERMISSION_LOCATION_WHENINUSE',
    };

    final enabled = enabledMacros();
    for (final entry in macroFor.entries) {
      if (!permissions.contains(entry.key)) continue;
      expect(
        enabled,
        contains(entry.value),
        reason: 'AppPermissions asks for ${entry.key} but the Podfile does '
            'not set ${entry.value}=1, so it is compiled out and always '
            'returns denied on iOS',
      );
    }
  });

  test('location stays when-in-use only', () {
    // The "always" strategy wants NSLocationAlwaysAndWhenInUseUsageDescription,
    // which the app has no honest reason to ship: site check-in is a single
    // reading taken while the technician is looking at the form.
    final enabled = enabledMacros();
    expect(enabled, contains('PERMISSION_LOCATION_WHENINUSE'));
    expect(enabled, isNot(contains('PERMISSION_LOCATION_ALWAYS')));
    expect(
      infoPlist.contains('NSLocationAlwaysAndWhenInUseUsageDescription'),
      isFalse,
      reason: 'the app never asks for background location',
    );
  });

  test('nothing is enabled that the app does not call', () {
    // Keeps the binary honest: each enabled macro costs an App Store question
    // and a privacy-manifest entry, so an unused one is pure liability.
    const expected = {
      'PERMISSION_CAMERA',
      'PERMISSION_PHOTOS',
      'PERMISSION_LOCATION_WHENINUSE',
    };
    expect(
      enabledMacros(),
      expected,
      reason: 'enable a macro only alongside the code that calls it and the '
          'Info.plist key that justifies it',
    );
  });

  test('the Podfile platform matches the Xcode project', () {
    // CocoaPods will happily build pods against a different floor than the
    // app, which surfaces later as confusing link errors.
    final projectTarget = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
        .firstMatch(File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync())!
        .group(1)!;
    final podfileTarget = RegExp(r"platform :ios, '([0-9.]+)'")
        .firstMatch(podfile.readAsStringSync())!
        .group(1)!;

    expect(podfileTarget, projectTarget);
  });
}
