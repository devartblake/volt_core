import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Calendar view modes for schedule display
enum CalendarViewMode {
  /// Split panel: Calendar (60%) + Upcoming tasks sidebar (40%)
  splitPanel,

  /// Daily agenda: Calendar (70%) + Selected day agenda (30%)
  dailyAgenda,

  /// Timeline: Mini calendar sidebar (20%) + Chronological timeline (80%)
  timeline,
}

/// Provider for current calendar view mode
final calendarViewModeProvider = StateProvider<CalendarViewMode>(
      (ref) => CalendarViewMode.splitPanel,
);

/// Extension for view mode display labels
extension CalendarViewModeX on CalendarViewMode {
  String get label {
    switch (this) {
      case CalendarViewMode.splitPanel:
        return 'Split Panel';
      case CalendarViewMode.dailyAgenda:
        return 'Daily Agenda';
      case CalendarViewMode.timeline:
        return 'Timeline';
    }
  }

  String get description {
    switch (this) {
      case CalendarViewMode.splitPanel:
        return 'Calendar with upcoming tasks sidebar';
      case CalendarViewMode.dailyAgenda:
        return 'Calendar with daily schedule';
      case CalendarViewMode.timeline:
        return 'Chronological task timeline';
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarViewMode.splitPanel:
        return Icons.view_sidebar;
      case CalendarViewMode.dailyAgenda:
        return Icons.view_day;
      case CalendarViewMode.timeline:
        return Icons.timeline;
    }
  }
}