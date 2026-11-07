import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/dashboard/presenter/dashboard_providers.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/domain/schedule_view_logic.dart';
import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository.dart';
import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository_impl.dart';
import 'package:voltcore/modules/schedule/presenter/controllers/schedule_assignment.dart';
import 'package:voltcore/modules/schedule/presenter/pages/schedule_page.dart';
import 'package:voltcore/modules/schedule/presenter/pages/schedule_task_detail_page.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/calendar_view_mode.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/schedule_calendar_timeline.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/task_assign_button.dart';

class _FakeRepo implements ScheduleRepository {
  _FakeRepo(this.tasks);

  List<TaskScheduleEntity> tasks;
  int saves = 0;

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    required DateTime? from,
    required DateTime? to,
  }) async =>
      List.of(tasks);

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) async {
    saves++;
    tasks = [for (final t in tasks) t.id == task.id ? task : t];
    return task;
  }

  @override
  Future<void> deleteTask(String id) async =>
      tasks = tasks.where((t) => t.id != id).toList();

  @override
  Future<TaskScheduleEntity?> getById(String id) async {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<TaskScheduleEntity> create(TaskScheduleEntity task) => saveTask(task);
  @override
  Future<TaskScheduleEntity> update(TaskScheduleEntity task) => saveTask(task);
  @override
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity task) => saveTask(task);
}

DateTime _today(int hour, [int minute = 0, int addDays = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + addDays, hour, minute);
}

TaskScheduleEntity _task(
  String id,
  DateTime at,
  String title, {
  String? who,
  String status = 'scheduled',
}) =>
    TaskScheduleEntity(
      id: id,
      scheduledAt: at,
      scheduledDate: DateTime(at.year, at.month, at.day),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      title: title,
      sourceType: 'manual',
      siteCode: 'S-$id',
      assignedToUserId: who,
      status: status,
    );

const _names = {'u1': 'Ana Rivera', 'u2': 'Bo Chen'};

Widget _app(
  _FakeRepo repo, {
  required Widget home,
  bool canAssign = true,
  double scale = 1,
  Map<String, String> names = _names,
  List<Override> extra = const [],
}) =>
    ProviderScope(
      overrides: [
        ...extra,
        scheduleRepositoryProvider.overrideWithValue(repo),
        canAssignScheduleProvider.overrideWithValue(canAssign),
        dashboardTechniciansProvider.overrideWith(
          (ref) async => (names: names, roster: names.keys.toList()),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

/// Pages have a sync indicator that animates forever; pump fixed steps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<TaskScheduleEntity> _seed() => [
      _task('1', _today(9), 'Morning check', who: 'u1'),
      _task('2', _today(13, 30), 'Afternoon service', who: 'u2'),
      _task('3', _today(11), 'Unclaimed job'),
      _task('4', _today(8, 0, 1), 'Tomorrow work', who: 'u1'),
    ];

void main() {
  testWidgets('Week view groups by day, in time order, with chips and names',
      (tester) async {
    _size(tester, const Size(800, 1280));
    final repo = _FakeRepo(_seed());
    await tester.pumpWidget(_app(repo, home: const SchedulePage()));
    await _settle(tester);

    await tester.tap(find.text('Week'));
    await _settle(tester);

    expect(find.text('Today'), findsWidgets);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('1:30 PM'), findsOneWidget);
    // Morning (9) is listed above mid-morning (11) which is above afternoon.
    final y9 = tester.getTopLeft(find.text('9:00 AM')).dy;
    final y11 = tester.getTopLeft(find.text('11:00 AM')).dy;
    final y13 = tester.getTopLeft(find.text('1:30 PM')).dy;
    expect(y9 < y11 && y11 < y13, isTrue);

    expect(find.text('Morning check'), findsOneWidget);
    expect(find.text('Unassigned'), findsWidgets);
    // Names appear on the chips and the cards.
    expect(find.text('Ana Rivera'), findsWidgets);
    expect(find.text('Bo Chen'), findsWidgets);
  });

  testWidgets('Day view shows only today and remembers the choice',
      (tester) async {
    _size(tester, const Size(800, 1280));
    final repo = _FakeRepo(_seed());
    final container = ProviderContainer(overrides: [
      scheduleRepositoryProvider.overrideWithValue(repo),
      canAssignScheduleProvider.overrideWithValue(true),
      dashboardTechniciansProvider.overrideWith(
          (ref) async => (names: _names, roster: _names.keys.toList())),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SchedulePage()),
    ));
    await _settle(tester);

    await tester.tap(find.text('Day'));
    await _settle(tester);
    expect(find.text('Tomorrow work'), findsNothing);
    expect(find.text('Morning check'), findsOneWidget);
    expect(container.read(scheduleSpanProvider).name, 'day');
  });

  testWidgets('technician chips filter the list', (tester) async {
    _size(tester, const Size(800, 1280));
    await tester.pumpWidget(
        _app(_FakeRepo(_seed()), home: const SchedulePage()));
    await _settle(tester);
    await tester.tap(find.text('Week'));
    await _settle(tester);

    expect(find.text('Morning check'), findsOneWidget);
    expect(find.text('Unclaimed job'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tech_filter_u2')));
    await _settle(tester);
    expect(find.text('Afternoon service'), findsOneWidget);
    expect(find.text('Morning check'), findsNothing);
    expect(find.text('Unclaimed job'), findsNothing);

    await tester.tap(find.byKey(const Key('tech_filter_unassigned')));
    await _settle(tester);
    expect(find.text('Unclaimed job'), findsOneWidget);
    expect(find.text('Afternoon service'), findsNothing);

    await tester.tap(find.byKey(const Key('tech_filter_all')));
    await _settle(tester);
    expect(find.text('Morning check'), findsOneWidget);
    expect(find.text('Afternoon service'), findsOneWidget);
  });

  testWidgets('technician query parameter opens that technician today',
      (tester) async {
    _size(tester, const Size(800, 1280));
    await tester.pumpWidget(_app(_FakeRepo(_seed()),
        home: const SchedulePage(technician: 'u1')));
    await _settle(tester);

    expect(find.text('Morning check'), findsOneWidget);
    expect(find.text('Tomorrow work'), findsNothing); // Day view, not week
    expect(find.text('Afternoon service'), findsNothing);
    expect(find.text('Unclaimed job'), findsNothing);
    final chip = tester.widget<ChoiceChip>(find.byKey(const Key('tech_filter_u1')));
    expect(chip.selected, isTrue);
  });

  testWidgets('technician=unassigned selects the Unassigned chip',
      (tester) async {
    _size(tester, const Size(800, 1280));
    await tester.pumpWidget(_app(_FakeRepo(_seed()),
        home: const SchedulePage(technician: 'unassigned')));
    await _settle(tester);

    expect(find.text('Unclaimed job'), findsOneWidget);
    expect(find.text('Morning check'), findsNothing);
  });

  testWidgets('dispatcher assigns from a card: saves, snackbar, list refreshes',
      (tester) async {
    _size(tester, const Size(800, 1280));
    final repo = _FakeRepo(_seed());
    await tester.pumpWidget(_app(repo, home: const SchedulePage()));
    await _settle(tester);
    await tester.tap(find.text('Day'));
    await _settle(tester);

    // The only unassigned task offers "Assign"; the others "Reassign".
    expect(find.text('Assign'), findsOneWidget);
    expect(find.text('Reassign'), findsNWidgets(2));
    await tester.tap(find.text('Assign'));
    await _settle(tester);

    expect(find.text('Assign technician'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assign_u2')));
    await _settle(tester);

    expect(repo.saves, 1);
    expect(repo.tasks.firstWhere((t) => t.id == '3').assignedToUserId, 'u2');
    expect(find.text('Assigned to Bo Chen.'), findsOneWidget);
    // The list reloaded: nothing is unassigned any more.
    expect(find.text('Assign'), findsNothing);
    expect(find.text('Reassign'), findsNWidgets(3));
  });

  testWidgets('technicians get no Assign action', (tester) async {
    _size(tester, const Size(800, 1280));
    await tester.pumpWidget(_app(_FakeRepo(_seed()),
        home: const SchedulePage(), canAssign: false));
    await _settle(tester);
    await tester.tap(find.text('Week'));
    await _settle(tester);

    expect(find.text('Assign'), findsNothing);
    expect(find.text('Reassign'), findsNothing);
    expect(find.text('Morning check'), findsOneWidget);
  });

  testWidgets('task detail offers Assign to dispatchers only', (tester) async {
    _size(tester, const Size(800, 1280));
    final repo = _FakeRepo(_seed());
    await tester.pumpWidget(_app(repo,
        home: const ScheduleTaskDetailPage(id: '3')));
    await _settle(tester);

    expect(find.text('Unassigned'), findsOneWidget);
    await tester.tap(find.text('Assign'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('assign_u1')));
    await _settle(tester);

    expect(repo.tasks.firstWhere((t) => t.id == '3').assignedToUserId, 'u1');
    expect(find.text('Ana Rivera'), findsOneWidget);

    await tester.pumpWidget(_app(_FakeRepo(_seed()),
        home: const ScheduleTaskDetailPage(id: '3'), canAssign: false));
    await _settle(tester);
    expect(find.text('Assign'), findsNothing);
  });

  testWidgets('month view (original calendar) still renders', (tester) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
        _app(_FakeRepo(_seed()), home: const SchedulePage()));
    await _settle(tester);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Month'), findsWidgets);
  });

  const sizes = {
    'phone': Size(360, 800),
    'tablet portrait': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
  };
  for (final e in sizes.entries) {
    for (final span in const ['Day', 'Week', 'Month']) {
      testWidgets('1.3x text, $span on ${e.key}: no overflow', (tester) async {
        _size(tester, e.value);
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            overflows.add(d.toString());
          } else {
            previous?.call(d);
          }
        };

        final long = _task('9', _today(10), 'A rather long scheduled task title',
            who: 'u1');
        await tester.pumpWidget(_app(
          _FakeRepo([
            ..._seed(),
            long.copyWith(address: '1234 Extremely Long Street Name, Brooklyn NY 11206'),
          ]),
          home: const SchedulePage(),
          scale: 1.3,
          names: const {
            'u1': 'Alexandria Montgomery-Fitzgerald',
            'u2': 'Bo Chen',
          },
        ));
        await _settle(tester);
        await tester.tap(find.descendant(
            of: find.byType(SegmentedButton<ScheduleSpan>),
            matching: find.text(span)));
        await _settle(tester);
        FlutterError.onError = previous;

        expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('month timeline layout', () {
    Future<void> openTimeline(WidgetTester tester,
        {required bool canAssign, double scale = 1}) async {
      await tester.pumpWidget(_app(
        _FakeRepo(_seed()),
        home: const SchedulePage(),
        canAssign: canAssign,
        scale: scale,
        extra: [
          calendarViewModeProvider
              .overrideWith((ref) => CalendarViewMode.timeline),
        ],
      ));
      await _settle(tester);
      await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<ScheduleSpan>),
          matching: find.text('Month')));
      await _settle(tester);
    }

    for (final e in sizes.entries) {
      testWidgets('1.3x text on ${e.key}: Assign/Reassign show, no overflow',
          (tester) async {
        _size(tester, e.value);
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            overflows.add(d.toString());
          } else {
            previous?.call(d);
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await openTimeline(tester, canAssign: true, scale: 1.3);
        FlutterError.onError = previous;
        expect(find.byType(ScheduleCalendarTimeline), findsOneWidget);
        // The list is lazy, so how many cards are built depends on the
        // viewport; every card built carries a button.
        expect(find.byType(TaskAssignButton), findsWidgets);
        expect(find.byTooltip('Reassign'), findsWidgets);
        expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
      });
    }

    testWidgets('tapping Assign on a timeline card opens the assign sheet',
        (tester) async {
      _size(tester, const Size(1280, 800));
      await openTimeline(tester, canAssign: true);
      await tester.tap(find.byTooltip('Assign'));
      await _settle(tester);
      expect(find.text('Assign technician'), findsOneWidget);
    });

    testWidgets('technicians get no Assign action on timeline cards',
        (tester) async {
      _size(tester, const Size(1280, 800));
      await openTimeline(tester, canAssign: false);
      expect(find.byType(ScheduleCalendarTimeline), findsOneWidget);
      expect(find.byType(TaskAssignButton), findsNothing);
    });
  });

  testWidgets('1.3x text: assign sheet fits on a phone', (tester) async {
    _size(tester, const Size(360, 800));
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        overflows.add(d.toString());
      } else {
        previous?.call(d);
      }
    };
    await tester.pumpWidget(_app(_FakeRepo(_seed()),
        home: const SchedulePage(technician: 'unassigned'), scale: 1.3));
    await _settle(tester);
    await tester.tap(find.text('Assign'));
    await _settle(tester);
    FlutterError.onError = previous;
    expect(find.text('Assign technician'), findsOneWidget);
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('Unassign clears the assignee', (tester) async {
    _size(tester, const Size(800, 1280));
    final repo = _FakeRepo(_seed());
    await tester.pumpWidget(
        _app(repo, home: const ScheduleTaskDetailPage(id: '1')));
    await _settle(tester);

    await tester.tap(find.text('Reassign'));
    await _settle(tester);
    expect(find.byKey(const Key('assign_none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assign_none')));
    await _settle(tester);

    expect(repo.tasks.firstWhere((t) => t.id == '1').assignedToUserId, isNull);
    expect(find.text('Task unassigned.'), findsOneWidget);
  });

  test('copyWith: null leaves the assignee, clearAssignee removes it', () {
    final t = _task('1', _today(9), 'x', who: 'u1');
    expect(t.copyWith(title: 'y').assignedToUserId, 'u1');
    expect(t.copyWith(assignToUserId: 'u2').assignedToUserId, 'u2');
    expect(t.copyWith(clearAssignee: true).assignedToUserId, isNull);
  });

  for (final mode in const [
    CalendarViewMode.splitPanel,
    CalendarViewMode.dailyAgenda
  ]) {
    testWidgets('${mode.name}: card Assign button opens the sheet; none for techs',
        (tester) async {
      _size(tester, const Size(800, 1280));
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) {
          overflows.add(d.toString());
        } else {
          previous?.call(d);
        }
      };
      final repo = _FakeRepo(_seed());
      final extra = [calendarViewModeProvider.overrideWith((ref) => mode)];
      await tester.pumpWidget(
          _app(repo, home: const SchedulePage(), scale: 1.3, extra: extra));
      await _settle(tester);
      await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<ScheduleSpan>),
          matching: find.text('Month')));
      await _settle(tester);

      final btn = find.byKey(const Key('assign_task_3'));
      expect(btn, findsOneWidget);
      expect(tester.getSize(btn).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Assign'), findsWidgets);
      await tester.tap(btn);
      await _settle(tester);
      expect(find.text('Assign technician'), findsOneWidget);
      await tester.tap(find.byKey(const Key('assign_u2')));
      await _settle(tester);
      expect(repo.tasks.firstWhere((t) => t.id == '3').assignedToUserId, 'u2');
      FlutterError.onError = previous;
      expect(overflows, isEmpty, reason: overflows.join('\n---\n'));

      await tester.pumpWidget(_app(_FakeRepo(_seed()),
          home: const SchedulePage(), canAssign: false, extra: extra));
      await _settle(tester);
      expect(find.byKey(const Key('assign_task_3')), findsNothing);
    });
  }
}
