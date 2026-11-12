import 'entities/task_schedule_entity.dart';

/// How much of the calendar the schedule shows at once.
enum ScheduleSpan { day, week, month }

/// Value of the technician filter that means "tasks nobody is assigned to".
const String unassignedFilter = 'unassigned';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d] (midnight).
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// First day (inclusive) and the day after the last (exclusive) of the span
/// around [focus].
({DateTime start, DateTime end}) spanRange(ScheduleSpan span, DateTime focus) {
  switch (span) {
    case ScheduleSpan.day:
      final s = dateOnly(focus);
      return (start: s, end: DateTime(s.year, s.month, s.day + 1));
    case ScheduleSpan.week:
      final s = startOfWeek(focus);
      return (start: s, end: DateTime(s.year, s.month, s.day + 7));
    case ScheduleSpan.month:
      return (
        start: DateTime(focus.year, focus.month),
        end: DateTime(focus.year, focus.month + 1),
      );
  }
}

/// Moves [focus] one [span] forward ([steps] > 0) or back.
DateTime shiftFocus(ScheduleSpan span, DateTime focus, int steps) {
  switch (span) {
    case ScheduleSpan.day:
      return DateTime(focus.year, focus.month, focus.day + steps);
    case ScheduleSpan.week:
      return DateTime(focus.year, focus.month, focus.day + 7 * steps);
    case ScheduleSpan.month:
      return DateTime(focus.year, focus.month + steps, 1);
  }
}

/// Tasks whose day falls inside the span around [focus].
List<TaskScheduleEntity> tasksInSpan(
  Iterable<TaskScheduleEntity> tasks,
  ScheduleSpan span,
  DateTime focus,
) {
  final r = spanRange(span, focus);
  return [
    for (final t in tasks)
      if (!dateOnly(t.scheduledAt).isBefore(r.start) &&
          dateOnly(t.scheduledAt).isBefore(r.end))
        t,
  ];
}

String? _assignee(TaskScheduleEntity t) {
  final raw = t.assignedToUserId?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

/// Keeps tasks for one technician. [technician] is null for everyone,
/// [unassignedFilter] for tasks nobody holds, otherwise a user id.
List<TaskScheduleEntity> filterByTechnician(
  Iterable<TaskScheduleEntity> tasks,
  String? technician,
) {
  if (technician == null) return tasks.toList();
  return [
    for (final t in tasks)
      if (technician == unassignedFilter
          ? _assignee(t) == null
          : _assignee(t) == technician)
        t,
  ];
}

/// Distinct assignee ids, in first-seen order.
List<String> technicianIdsIn(Iterable<TaskScheduleEntity> tasks) {
  final seen = <String>{};
  for (final t in tasks) {
    final id = _assignee(t);
    if (id != null) seen.add(id);
  }
  return seen.toList();
}

/// Display name for a user id; ids without a known name read
/// "Technician" plus the last four characters so rows stay distinct.
String technicianLabel(String id, Map<String, String> names) {
  final n = names[id]?.trim() ?? '';
  if (n.isNotEmpty) return n;
  final tail = id.length > 4 ? id.substring(id.length - 4) : id;
  return 'Technician $tail';
}

/// Assignee name for a task, or null when unassigned.
String? assigneeLabel(TaskScheduleEntity task, Map<String, String> names) {
  final id = _assignee(task);
  return id == null ? null : technicianLabel(id, names);
}

/// Tasks grouped by day (earliest day first), each day in time order.
Map<DateTime, List<TaskScheduleEntity>> groupTasksByDay(
  Iterable<TaskScheduleEntity> tasks,
) {
  final grouped = <DateTime, List<TaskScheduleEntity>>{};
  for (final t in tasks) {
    grouped.putIfAbsent(dateOnly(t.scheduledAt), () => []).add(t);
  }
  final days = grouped.keys.toList()..sort();
  return {
    for (final d in days)
      d: grouped[d]!..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
  };
}

/// "9:30 AM".
String formatScheduleTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Today", "Tomorrow", "Yesterday" or "Tue, Nov 3".
String formatDayHeader(DateTime date, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final d = dateOnly(date);
  if (d == today) return 'Today';
  if (d == DateTime(today.year, today.month, today.day + 1)) return 'Tomorrow';
  if (d == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// Label for the range being viewed ("Tue, Nov 3", "Nov 2 - 8", "November 2026").
String formatSpanLabel(ScheduleSpan span, DateTime focus, {DateTime? now}) {
  switch (span) {
    case ScheduleSpan.day:
      final base = formatDayHeader(focus, now: now);
      return base.contains(',') ? '$base, ${focus.year}' : base;
    case ScheduleSpan.week:
      final s = startOfWeek(focus);
      final e = DateTime(s.year, s.month, s.day + 6);
      final end = s.month == e.month ? '${e.day}' : '${_months[e.month - 1]} ${e.day}';
      return '${_months[s.month - 1]} ${s.day} - $end';
    case ScheduleSpan.month:
      const full = [
        'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December',
      ];
      return '${full[focus.month - 1]} ${focus.year}';
  }
}

/// Short month/day, e.g. "Nov 3".
String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
