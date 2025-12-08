// Helpers for formatting and relative time strings.
//
// Requires `intl` in pubspec.yaml:
//   dependencies:
//     intl: ^0.x.x

import 'package:intl/intl.dart';

extension DateTimeFormattingX on DateTime {
  /// e.g. "Jan 5, 2025"
  String toShortDate() => DateFormat.yMMMd().format(this);

  /// e.g. "Jan 5, 2025 3:45 PM"
  String toShortDateTime() => DateFormat.yMMMd().add_jm().format(this);

  /// Simple "x min/h/d ago" formatting for recency labels, etc.
  String toRelativeTime({DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(this);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      final w = diff.inDays ~/ 7;
      return '$w week${w == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 365) {
      final m = diff.inDays ~/ 30;
      return '$m month${m == 1 ? '' : 's'} ago';
    }
    final y = diff.inDays ~/ 365;
    return '$y year${y == 1 ? '' : 's'} ago';
  }
}