import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/path_resolver.dart';

void main() {
  group('PathResolver.relativeUnderMarker', () {
    test('re-anchors an iOS-style PDF path', () {
      const stored =
          '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
          'pdfs/inspections/SITE_2026-01-01/inspection_123.pdf';
      expect(
        PathResolver.relativeUnderMarker(stored),
        'pdfs/inspections/SITE_2026-01-01/inspection_123.pdf',
      );
    });

    test('handles Windows separators for signatures', () {
      final stored =
          r'C:\Users\me\AppData\Roaming\voltcore\signatures\inspections\a.png';
      expect(
        PathResolver.relativeUnderMarker(stored),
        'signatures/inspections/a.png',
      );
    });

    test('re-anchors a photos path', () {
      const stored = '/data/user/0/app/files/photos/maintenance/m1/p.jpg';
      expect(
        PathResolver.relativeUnderMarker(stored),
        'photos/maintenance/m1/p.jpg',
      );
    });

    test('returns null when no managed marker is present', () {
      expect(
        PathResolver.relativeUnderMarker('/some/other/place/file.txt'),
        isNull,
      );
    });
  });
}
