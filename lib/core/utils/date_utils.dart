import 'package:flutter/material.dart';

class AppDateUtils {
  /// Format as `YYYY-MM-DD`
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Format as `YYYY-MM-DD HH:mm`
  static String formatDateTime(DateTime dateTime) {
    final date = formatDate(dateTime);
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  /// Very simple "time ago" helper.
  static String timeAgo(DateTime dateTime, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';

    final weeks = diff.inDays ~/ 7;
    return '${weeks}w ago';
  }

  /// Utility to pick a date range in the UI (if needed later).
  static Future<DateTimeRange?> pickDateRange(
      BuildContext context, {
        DateTimeRange? initial,
      }) {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 5);

    return showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: initial ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );
  }
}