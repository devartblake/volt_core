import '../../schedule/domain/entities/task_schedule_entity.dart';
import 'dashboard_summary.dart';

/// One row of "Who is on what today": a technician (or the unassigned pool)
/// with the day's tasks.
class TechnicianDay {
  const TechnicianDay({
    required this.userId,
    required this.name,
    required this.tasks,
    required this.nextTaskAt,
  });

  /// Null for the unassigned row.
  final String? userId;
  final String name;

  /// Today's tasks (not cancelled), earliest first.
  final List<TaskScheduleEntity> tasks;

  /// Start of the earliest task still open, or null when none is.
  final DateTime? nextTaskAt;

  bool get isUnassigned => userId == null;
  int get count => tasks.length;
  int get openCount => tasks.where((t) => isOpenTaskStatus(t.status)).length;
}

const String unassignedLabel = 'Unassigned';

/// Groups today's tasks by assignee.
///
/// [names] maps a user id to a display name; an id with no name is shown as
/// "Technician" plus the last four characters of the id so rows stay distinct.
/// Technicians in [roster] appear even with no tasks (count 0). Rows are
/// sorted by name, with "Unassigned" last and only present when it has tasks.
List<TechnicianDay> buildTechnicianDays(
  Iterable<TaskScheduleEntity> tasks, {
  required DateTime now,
  Map<String, String> names = const {},
  Iterable<String> roster = const [],
}) {
  final today = DateTime(now.year, now.month, now.day);
  final byUser = <String?, List<TaskScheduleEntity>>{};

  for (final id in roster) {
    byUser.putIfAbsent(id, () => []);
  }
  for (final t in tasks) {
    final d = t.scheduledDate;
    if (DateTime(d.year, d.month, d.day) != today) continue;
    if (t.status == 'cancelled') continue;
    final raw = t.assignedToUserId?.trim();
    final id = (raw == null || raw.isEmpty) ? null : raw;
    byUser.putIfAbsent(id, () => []).add(t);
  }

  String nameFor(String id) {
    final n = names[id]?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final tail = id.length > 4 ? id.substring(id.length - 4) : id;
    return 'Technician $tail';
  }

  TechnicianDay day(String? id, List<TaskScheduleEntity> list) {
    final sorted = [...list]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final open = sorted.where((t) => isOpenTaskStatus(t.status));
    return TechnicianDay(
      userId: id,
      name: id == null ? unassignedLabel : nameFor(id),
      tasks: sorted,
      nextTaskAt: open.isEmpty ? null : open.first.scheduledAt,
    );
  }

  final rows = [
    for (final e in byUser.entries)
      if (e.key != null) day(e.key, e.value),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final unassigned = byUser[null];
  if (unassigned != null && unassigned.isNotEmpty) {
    rows.add(day(null, unassigned));
  }
  return rows;
}
