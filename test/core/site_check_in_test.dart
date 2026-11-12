import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/location/site_check_in.dart';

void main() {
  SiteCheckIn at({
    double latitude = 40.7061,
    double longitude = -73.9369,
    double? accuracy,
  }) =>
      SiteCheckIn(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        capturedAt: DateTime.utc(2026, 9, 16, 14, 30),
      );

  group('plausibility', () {
    test('rejects Null Island', () {
      // (0, 0) is in the Gulf of Guinea and is what a failed fix or an
      // uninitialised variable looks like. Storing it would put an inspection
      // 4,000 km off the African coast.
      expect(SiteCheckIn.isPlausible(0, 0), isFalse);
      expect(SiteCheckIn.fromJson({'latitude': 0, 'longitude': 0}), isNull);
    });

    test('rejects out-of-range coordinates', () {
      expect(SiteCheckIn.isPlausible(91, 0), isFalse);
      expect(SiteCheckIn.isPlausible(-91, 0), isFalse);
      expect(SiteCheckIn.isPlausible(0, 181), isFalse);
      expect(SiteCheckIn.isPlausible(0, -181), isFalse);
      expect(SiteCheckIn.isPlausible(double.nan, 0), isFalse);
    });

    test('accepts a real Brooklyn position', () {
      expect(SiteCheckIn.isPlausible(40.7061, -73.9369), isTrue);
    });

    test('accepts a legitimate zero on one axis', () {
      // Only the pair (0, 0) is suspect. The Greenwich meridian and the equator
      // are real places, and rejecting either would be wrong.
      expect(SiteCheckIn.isPlausible(51.4778, 0), isTrue);
      expect(SiteCheckIn.isPlausible(0, -73.9369), isTrue);
    });
  });

  group('quality', () {
    test('bands the accuracy the OS reported', () {
      expect(at(accuracy: 5).quality, SiteCheckInQuality.good);
      expect(at(accuracy: 25).quality, SiteCheckInQuality.good);
      expect(at(accuracy: 60).quality, SiteCheckInQuality.fair);
      expect(at(accuracy: 100).quality, SiteCheckInQuality.fair);
      // 500 m is a cell-tower fix: the technician could be anywhere in the
      // neighbourhood, which is not evidence of being in the plant room.
      expect(at(accuracy: 500).quality, SiteCheckInQuality.poor);
      expect(at().quality, SiteCheckInQuality.unknown);
    });

    test('a rough or unknown fix is flagged as weak', () {
      expect(at(accuracy: 5).quality.isWeak, isFalse);
      expect(at(accuracy: 60).quality.isWeak, isFalse);
      expect(at(accuracy: 500).quality.isWeak, isTrue);
      expect(at().quality.isWeak, isTrue);
    });
  });

  group('json', () {
    test('round-trips', () {
      final original = at(accuracy: 12.5);
      final restored = SiteCheckIn.fromJson(original.toJson())!;

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracyMeters, 12.5);
      expect(restored.capturedAt, original.capturedAt);
    });

    test('survives a record that never had one', () {
      // Every inspection and maintenance record written before this feature.
      expect(SiteCheckIn.fromJson(null), isNull);
      expect(SiteCheckIn.fromJson(const {}), isNull);
      expect(SiteCheckIn.fromJson('not a map'), isNull);
    });

    test('accepts numbers that arrived as strings', () {
      // jsonb round trips can hand back either, depending on how the row was
      // written.
      final restored = SiteCheckIn.fromJson({
        'latitude': '40.7061',
        'longitude': '-73.9369',
        'accuracy_m': '8',
      });
      expect(restored, isNotNull);
      expect(restored!.latitude, closeTo(40.7061, 0.00001));
      expect(restored.accuracyMeters, 8);
    });

    test('a missing capture time does not lose the position', () {
      final restored = SiteCheckIn.fromJson({
        'latitude': 40.7061,
        'longitude': -73.9369,
      });
      expect(restored, isNotNull);
      expect(restored!.capturedAt, isNotNull);
    });
  });

  test('formats to six decimals and no further', () {
    // ~0.1 m, far finer than any phone GPS. More digits are noise that reads
    // as precision the fix does not have.
    expect(
      SiteCheckIn(
        latitude: 40.70611111111,
        longitude: -73.93691111111,
        capturedAt: DateTime.utc(2026),
      ).formatted,
      '40.706111, -73.936911',
    );
  });

  test('builds a geo: URI both platforms open', () {
    expect(at().mapsUri, 'geo:40.7061,-73.9369?q=40.7061,-73.9369');
  });
}
