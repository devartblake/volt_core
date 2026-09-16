import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the manifest against the two ways a permission change breaks a
/// working feature.
///
/// Neither is caught by the analyzer or by any widget test: the manifest is
/// XML the Dart toolchain never reads, and the symptom only appears on a real
/// device.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final capture =
      File('lib/shared/presenter/widgets/photo_attachments_section.dart')
          .readAsStringSync();

  bool declares(String permission) =>
      manifest.contains('android.permission.$permission');

  group('AndroidManifest', () {
    test('declares what the app actually uses', () {
      // INTERNET: Supabase and the sync queue.
      expect(declares('INTERNET'), isTrue);
      // ACCESS_NETWORK_STATE: connectivity_plus reports "none" without it on
      // some OEM builds, which makes the queue think it is永 offline.
      expect(declares('ACCESS_NETWORK_STATE'), isTrue);
      // CAMERA + media: the photo attachment widget.
      expect(declares('CAMERA'), isTrue);
      expect(declares('READ_MEDIA_IMAGES'), isTrue);
    });

    test('CAMERA is declared together with a runtime request', () {
      // The trap this exists for: ACTION_IMAGE_CAPTURE — which image_picker
      // uses — works WITHOUT the CAMERA permission declared. Declaring it
      // flips the contract, and Android then requires the runtime grant or the
      // capture fails with a SecurityException.
      //
      // So the manifest line and the ensureCamera() call are one change. Ship
      // either alone and photo capture breaks on every Android device.
      expect(
        declares('CAMERA'),
        isTrue,
        reason: 'manifest lost the CAMERA declaration',
      );
      expect(
        capture.contains('AppPermissions.ensureCamera()'),
        isTrue,
        reason: 'CAMERA is declared but nothing requests it at runtime — '
            'ACTION_IMAGE_CAPTURE will throw SecurityException',
      );
    });

    test('legacy storage reads stay capped so they do not shadow the new ones',
        () {
      // READ_EXTERNAL_STORAGE without maxSdkVersion makes Play warn about
      // broad access on Android 13+, where READ_MEDIA_IMAGES is the real
      // permission.
      expect(
        RegExp(
          r'READ_EXTERNAL_STORAGE"\s*\n?\s*android:maxSdkVersion="32"',
        ).hasMatch(manifest),
        isTrue,
        reason: 'READ_EXTERNAL_STORAGE must keep android:maxSdkVersion="32"',
      );
      expect(
        RegExp(
          r'WRITE_EXTERNAL_STORAGE"\s*\n?\s*android:maxSdkVersion="28"',
        ).hasMatch(manifest),
        isTrue,
        reason: 'WRITE_EXTERNAL_STORAGE must keep android:maxSdkVersion="28"',
      );
    });

    test('hardware features are optional, so the app stays installable', () {
      // Declaring CAMERA implies <uses-feature android:name="android.hardware
      // .camera"> as REQUIRED unless stated otherwise, which removes the app
      // from Play for any device without one. Same for GPS.
      for (final feature in ['android.hardware.camera', 'android.hardware.location.gps']) {
        final block = RegExp(
          'uses-feature\\s+android:name="$feature"\\s+android:required="false"',
        );
        expect(
          block.hasMatch(manifest.replaceAll(RegExp(r'\s+'), ' ')),
          isTrue,
          reason: '$feature must be android:required="false"',
        );
      }
    });
  });

  group('location', () {
    test('is declared, and something actually uses it', () {
      // This assertion is the inverse of what it was when the permission was
      // first declared: it used to guard that NOTHING called ensureLocation,
      // because no location package existed and a prompt would have bought
      // nothing. Site check-in is that feature, so the rule flips — the
      // permission and a real caller now travel together, exactly like CAMERA.
      expect(declares('ACCESS_FINE_LOCATION'), isTrue);
      expect(declares('ACCESS_COARSE_LOCATION'), isTrue);

      expect(
        File('pubspec.yaml').readAsStringSync().contains('geolocator:'),
        isTrue,
        reason: 'location is declared but no package can read a position',
      );

      final callers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('app_permissions.dart'))
          .where((f) => f.readAsStringSync().contains('ensureLocation'))
          .toList();

      expect(
        callers,
        isNotEmpty,
        reason: 'ACCESS_FINE_LOCATION is declared but nothing requests it — '
            'either wire the feature or drop the permission, because a '
            'declared-and-unused location permission is a Play Data Safety '
            'question with no answer',
      );
    });

    test('check-in reaches both forms, not just inspections', () {
      // Maintenance is work done at a place too. Wiring one and not the other
      // is the kind of asymmetry that gets noticed months later by whoever is
      // reading the reports.
      for (final form in [
        'lib/modules/inspections/presenter/pages/inspection_form_page.dart',
        'lib/modules/maintenance/presenter/pages/maintenance_form_page.dart',
      ]) {
        expect(
          File(form).readAsStringSync().contains('SiteCheckInTile'),
          isTrue,
          reason: '$form lost its site check-in',
        );
      }
    });
  });
}
