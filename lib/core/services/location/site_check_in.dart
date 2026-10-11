/// Where a form was filled in, captured once when the technician taps
/// "Check in".
///
/// Deliberately a snapshot, not live tracking. The app records the position at
/// the moment of check-in and never again — the question a report answers is
/// "were you actually at the site?", not "where is this person now". Anything
/// continuous would be a different feature with a different consent story.
///
/// Shared by inspections and maintenance: both are work done *at a place*, and
/// two copies of this would drift.
class SiteCheckIn {
  const SiteCheckIn({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy the OS reported, in metres. Null when it did not say.
  ///
  /// Kept because it is the difference between "at the site" and "somewhere in
  /// this postcode": a fix good to 2000 m inside a generator room is not
  /// evidence of anything, and a reader needs to know that.
  final double? accuracyMeters;

  final DateTime capturedAt;

  /// Six decimal places is roughly 0.1 m — far finer than any phone GPS, and
  /// the point past which more digits are noise.
  String get formatted =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// How trustworthy the fix is, for the UI to say plainly.
  ///
  /// The thresholds are deliberately coarse. A phone reporting 8 m and one
  /// reporting 12 m are the same answer in practice; 500 m is a cell-tower fix
  /// and means the technician could be anywhere in the neighbourhood.
  SiteCheckInQuality get quality {
    final accuracy = accuracyMeters;
    if (accuracy == null) return SiteCheckInQuality.unknown;
    if (accuracy <= 25) return SiteCheckInQuality.good;
    if (accuracy <= 100) return SiteCheckInQuality.fair;
    return SiteCheckInQuality.poor;
  }

  /// A geo: URI, which opens the built-in maps app on both platforms.
  String get mapsUri => 'geo:$latitude,$longitude?q=$latitude,$longitude';

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyMeters,
        'captured_at': capturedAt.toIso8601String(),
      };

  /// Null when [json] is absent or unusable, so a record written before this
  /// feature — or by a build that stored something odd — still loads.
  static SiteCheckIn? fromJson(Object? json) {
    if (json is! Map) return null;

    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);
    if (latitude == null || longitude == null) return null;
    if (!isPlausible(latitude, longitude)) return null;

    return SiteCheckIn(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: _toDouble(json['accuracy_m']),
      capturedAt:
          DateTime.tryParse('${json['captured_at']}')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }

  /// Rejects coordinates outside the real range, and Null Island.
  ///
  /// (0, 0) is in the Gulf of Guinea and is what a failed fix or an
  /// uninitialised variable looks like. No generator the company services is
  /// there, so treating it as "no position" is right far more often than it is
  /// wrong.
  static bool isPlausible(double latitude, double longitude) {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0 && longitude == 0) return false;
    return true;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

enum SiteCheckInQuality { good, fair, poor, unknown }

extension SiteCheckInQualityX on SiteCheckInQuality {
  String get label => switch (this) {
        SiteCheckInQuality.good => 'Good signal',
        SiteCheckInQuality.fair => 'Approximate',
        SiteCheckInQuality.poor => 'Rough fix only',
        SiteCheckInQuality.unknown => 'Accuracy unknown',
      };

  /// Whether the reader should treat this as weak evidence of being on site.
  bool get isWeak =>
      this == SiteCheckInQuality.poor || this == SiteCheckInQuality.unknown;
}
