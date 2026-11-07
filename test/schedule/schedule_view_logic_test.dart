import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/domain/schedule_view_logic.dart';

TaskScheduleEntity _task(String id, DateTime at, {String? who}) =>
    TaskScheduleEntity(
      id: id,
      scheduledAt: at,
      scheduledDate: DateTime(at.year, at.month, at.day),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      title: id,
      sourceType: 'manual',
      assignedToUserId: who,
    );

void main() {
  // Tuesday 3 Nov 2026.
  final focus = DateTime(2026, 11, 3, 12);

  group('spans', () {
    test('week runs Monday to Sunday', () {
      final r = spanRange(ScheduleSpan.week, focus);
      expect(r.start, DateTime(2026, 11, 2));
      expect(r.end, DateTime(2026, 11, 9));
    });

    test('week starting on a Sunday belongs to the previous Monday', () {
      expect(startOfWeek(DateTime(2026, 11, 8, 20)), DateTime(2026, 11, 2));
    });

    test('month and day ranges', () {
      expect(spanRange(ScheduleSpan.month, focus).end, DateTime(2026, 12));
      expect(spanRange(ScheduleSpan.day, focus).start, DateTime(2026, 11, 3));
      expect(spanRange(ScheduleSpan.month, DateTime(2026, 12, 15)).end,
          DateTime(2027));
    });

    test('shiftFocus moves by one span', () {
      expect(shiftFocus(ScheduleSpan.day, focus, 1), DateTime(2026, 11, 4));
      expect(shiftFocus(ScheduleSpan.week, focus, -1), DateTime(2026, 10, 27));
      expect(shiftFocus(ScheduleSpan.month, focus, 2), DateTime(2027, 1, 1));
    });

    test('tasksInSpan includes the whole last day and excludes the next', () {
      final tasks = [
        _task('mon', DateTime(2026, 11, 2, 0, 5)),
        _task('sun-late', DateTime(2026, 11, 8, 23, 59)),
        _task('next-mon', DateTime(2026, 11, 9, 8)),
        _task('prev-sun', DateTime(2026, 11, 1, 23)),
      ];
      final ids =
          tasksInSpan(tasks, ScheduleSpan.week, focus).map((t) => t.id);
      expect(ids, ['mon', 'sun-late']);
    });
  });

  group('technician filter', () {
    final tasks = [
      _task('a', DateTime(2026, 11, 3, 9), who: 'u1'),
      _task('b', DateTime(2026, 11, 3, 10)),
      _task('c', DateTime(2026, 11, 3, 11), who: '  '),
      _task('d', DateTime(2026, 11, 3, 12), who: 'u2'),
      _task('e', DateTime(2026, 11, 4, 8), who: 'u1'),
    ];

    test('null keeps everything', () {
      expect(filterByTechnician(tasks, null), hasLength(5));
    });

    test('a user id keeps only that technician', () {
      expect(filterByTechnician(tasks, 'u1').map((t) => t.id), ['a', 'e']);
    });

    test('unassigned keeps empty and blank assignees', () {
      expect(filterByTechnician(tasks, unassignedFilter).map((t) => t.id),
          ['b', 'c']);
    });

    test('technicianIdsIn lists each assignee once in first-seen order', () {
      expect(technicianIdsIn(tasks), ['u1', 'u2']);
    });

    test('labels fall back to a short id', () {
      expect(technicianLabel('u1', {'u1': ' Ana '}), 'Ana');
      expect(technicianLabel('abcdef123456', const {}), 'Technician 3456');
      expect(technicianLabel('ab', const {}), 'Technician ab');
      expect(assigneeLabel(tasks[1], const {}), isNull);
      expect(assigneeLabel(tasks[0], {'u1': 'Ana'}), 'Ana');
    });
  });

  group('grouping and formatting', () {
    test('groups by day, days ascending, times ascending within a day', () {
      final grouped = groupTasksByDay([
        _task('late', DateTime(2026, 11, 4, 15)),
        _task('pm', DateTime(2026, 11, 3, 15)),
        _task('am', DateTime(2026, 11, 3, 8, 30)),
      ]);
      expect(grouped.keys, [DateTime(2026, 11, 3), DateTime(2026, 11, 4)]);
      expect(grouped[DateTime(2026, 11, 3)]!.map((t) => t.id), ['am', 'pm']);
    });

    test('time labels', () {
      expect(formatScheduleTime(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(formatScheduleTime(DateTime(2026, 1, 1, 12)), '12:00 PM');
      expect(formatScheduleTime(DateTime(2026, 1, 1, 15, 45)), '3:45 PM');
    });

    test('day headers', () {
      final now = DateTime(2026, 11, 3, 10);
      expect(formatDayHeader(DateTime(2026, 11, 3), now: now), 'Today');
      expect(formatDayHeader(DateTime(2026, 11, 4), now: now), 'Tomorrow');
      expect(formatDayHeader(DateTime(2026, 11, 2), now: now), 'Yesterday');
      expect(formatDayHeader(DateTime(2026, 11, 10), now: now), 'Tue, Nov 10');
    });

    test('span labels', () {
      final now = DateTime(2026, 11, 3);
      expect(formatSpanLabel(ScheduleSpan.week, focus), 'Nov 2 - 8');
      expect(formatSpanLabel(ScheduleSpan.week, DateTime(2026, 10, 29)),
          'Oct 26 - Nov 1');
      expect(formatSpanLabel(ScheduleSpan.month, focus), 'November 2026');
      expect(formatSpanLabel(ScheduleSpan.day, focus, now: now), 'Today');
      expect(formatSpanLabel(ScheduleSpan.day, DateTime(2026, 11, 12), now: now),
          'Thu, Nov 12, 2026');
    });
  });
}
