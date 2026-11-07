import 'package:flutter_riverpod/legacy.dart';

import '../../domain/schedule_view_logic.dart';

/// Schedule view mode enum
enum ScheduleView { list, calendar }

/// Time range filter enum
enum TimeRange { week, month, year, all }

/// Provider for current schedule view
final scheduleViewProvider =
    StateProvider<ScheduleView>((ref) => ScheduleView.calendar);

/// Provider for current time range filter
final timeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.month);

/// Provider for selected date in calendar
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Day / Week / Month choice, remembered while the app is open. Month is the
/// original calendar screen.
final scheduleSpanProvider =
    StateProvider<ScheduleSpan>((ref) => ScheduleSpan.month);
