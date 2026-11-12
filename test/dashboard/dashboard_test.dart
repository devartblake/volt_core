import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/dashboard/domain/dashboard_summary.dart';
import 'package:voltcore/modules/dashboard/domain/technician_day.dart';
import 'package:voltcore/modules/dashboard/presenter/widgets/dashboard_sections.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/work_orders/presenter/work_order_workload.dart';

final _now = DateTime(2026, 11, 3, 14, 30);

TaskScheduleEntity _task(
  String id,
  DateTime when, {
  String status = 'scheduled',
  String address = '',
  String title = 'Generator service',
  String? assignee,
}) =>
    TaskScheduleEntity(
      id: id,
      scheduledAt: when,
      scheduledDate: DateTime(when.year, when.month, when.day),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      title: title,
      sourceType: 'maintenance_record',
      address: address,
      status: status,
      assignedToUserId: assignee,
    );

const _routes = AttentionRoutes(
  schedule: '/schedule',
  jobs: '/jobs',
  inspections: '/inspections',
  fleetLog: '/fleet/log',
);

AttentionInputs _inputs(
  DashboardAudience audience, {
  DashboardSummary summary = DashboardSummary.empty,
  WorkOrderWorkload? workload,
  int red = 0,
  int? daily,
}) =>
    AttentionInputs(
      audience: audience,
      summary: summary,
      workload: workload,
      redGradeSites: red,
      vehiclesNeedingDailyCheck: daily,
      routes: _routes,
    );

void main() {
  group('DashboardSummary', () {
    test('overdue is open work dated before today, oldest first', () {
      final s = DashboardSummary.fromTasks([
        _task('a', DateTime(2026, 11, 1, 9)),
        _task('done', DateTime(2026, 11, 1, 9), status: 'completed'),
        _task('gone', DateTime(2026, 10, 30, 9), status: 'cancelled'),
        _task('b', DateTime(2026, 10, 28, 9), status: 'in_progress'),
      ], now: _now);

      expect(s.overdue.map((t) => t.id), ['b', 'a']);
    });

    test('completed past work is not overdue and counts as done this week', () {
      final s = DashboardSummary.fromTasks([
        _task('x', DateTime(2026, 11, 2), status: 'completed'),
        _task('old', DateTime(2026, 10, 1), status: 'completed'),
      ], now: _now);

      expect(s.overdue, isEmpty);
      expect(s.completedThisWeek, 1);
    });

    test('today lists non-cancelled tasks in time order with open/done counts',
        () {
      final s = DashboardSummary.fromTasks([
        _task('late', DateTime(2026, 11, 3, 16)),
        _task('early', DateTime(2026, 11, 3, 8), status: 'completed'),
        _task('mid', DateTime(2026, 11, 3, 12), status: 'in_progress'),
        _task('no', DateTime(2026, 11, 3, 10), status: 'cancelled'),
      ], now: _now);

      expect(s.today.map((t) => t.id), ['early', 'mid', 'late']);
      expect(s.todayOpen, 2);
      expect(s.todayDone, 1);
    });

    test('upcoming counts open tasks in the next seven days only', () {
      final s = DashboardSummary.fromTasks([
        _task('tomorrow', DateTime(2026, 11, 4, 9)),
        _task('in7', DateTime(2026, 11, 10, 9)),
        _task('in9', DateTime(2026, 11, 12, 9)),
        _task('cancelled', DateTime(2026, 11, 5, 9), status: 'cancelled'),
      ], now: _now);

      expect(s.upcomingWeek, 2);
    });
  });

  group('DashboardAudience', () {
    test('each role has its own audience', () {
      expect(DashboardAudience.of(UserRole.tech), DashboardAudience.field);
      expect(
          DashboardAudience.of(UserRole.dispatcher), DashboardAudience.dispatch);
      expect(
          DashboardAudience.of(UserRole.supervisor), DashboardAudience.review);
      expect(DashboardAudience.of(UserRole.admin), DashboardAudience.admin);
      expect(DashboardAudience.field.headline, 'Your day');
    });
  });

  group('buildAttention', () {
    final overdueSummary = DashboardSummary.fromTasks(
        [_task('o', DateTime(2026, 11, 1))],
        now: _now);
    const workload =
        WorkOrderWorkload(open: 5, dueToday: 1, overdue: 2, unassigned: 3);

    test('nothing to flag gives an empty list', () {
      expect(buildAttention(_inputs(DashboardAudience.admin)), isEmpty);
    });

    test('overdue work comes first', () {
      final items = buildAttention(_inputs(
        DashboardAudience.admin,
        summary: overdueSummary,
        daily: 2,
      ));
      expect(items.first.label, '1 overdue task');
      expect(items.first.severity, AttentionSeverity.critical);
      expect(items.first.route, '/schedule');
    });

    test('a technician is told their own daily check is due', () {
      final items = buildAttention(_inputs(DashboardAudience.field, daily: 1));
      expect(items.single.label, 'Daily vehicle check not done');
      expect(items.single.route, '/fleet/log');
    });

    test('a manager is told how many vehicles lack a daily check', () {
      final items = buildAttention(_inputs(DashboardAudience.admin, daily: 3));
      expect(items.single.label, '3 vehicles without a daily check');
    });

    test('no fleet access means no vehicle item', () {
      expect(buildAttention(_inputs(DashboardAudience.field, daily: null)),
          isEmpty);
      expect(buildAttention(_inputs(DashboardAudience.field, daily: 0)),
          isEmpty);
    });

    test('unassigned jobs are for dispatch and admin only', () {
      List<String> labels(DashboardAudience a) => buildAttention(
              _inputs(a, workload: workload))
          .map((i) => i.label)
          .toList();

      expect(labels(DashboardAudience.dispatch), contains('3 unassigned jobs'));
      expect(labels(DashboardAudience.admin), contains('3 unassigned jobs'));
      expect(labels(DashboardAudience.field), isNot(contains('3 unassigned jobs')));
      // Overdue jobs matter to everyone.
      expect(labels(DashboardAudience.field), contains('2 overdue jobs'));
    });

    test('red-grade sites are for review and admin only', () {
      expect(
          buildAttention(_inputs(DashboardAudience.review, red: 4))
              .single
              .label,
          '4 red-grade sites');
      expect(buildAttention(_inputs(DashboardAudience.field, red: 4)), isEmpty);
    });

    test('singular wording for one', () {
      final items = buildAttention(_inputs(
        DashboardAudience.dispatch,
        workload: const WorkOrderWorkload(
            open: 1, dueToday: 0, overdue: 1, unassigned: 1),
      ));
      expect(items.map((i) => i.label), contains('1 overdue job'));
      expect(items.map((i) => i.label), contains('1 unassigned job'));
    });
  });

  group('dashboard widgets at 1.3x text', () {
    const sizes = {
      'phone': Size(360, 800),
      'tablet': Size(1280, 800),
    };

    Widget host(Widget child) => MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: c!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    for (final entry in sizes.entries) {
      testWidgets('cards and actions fit on a ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final summary = DashboardSummary.fromTasks([
          _task('1', DateTime(2026, 11, 3, 9),
              address: '2151 WASHINGTON AVENUE, Bronx, NY 10457'),
          _task('2', DateTime(2026, 11, 3, 11), status: 'completed'),
          _task('o', DateTime(2026, 11, 1)),
        ], now: _now);

        await tester.pumpWidget(host(Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            AttentionCard(
              items: buildAttention(_inputs(
                DashboardAudience.admin,
                summary: summary,
                daily: 2,
                red: 3,
              )),
              onOpen: (_) {},
            ),
            const SizedBox(height: 16),
            TodayCard(
                summary: summary, onOpenTask: (_) {}, onOpenSchedule: () {}),
            const SizedBox(height: 16),
            QuickActionsGrid(
              actions: const [
                DashboardAction(
                    label: 'New maintenance',
                    icon: Icons.build_circle_outlined,
                    route: '/m',
                    routeName: 'm'),
                DashboardAction(
                    label: 'Schedule a task',
                    icon: Icons.event_outlined,
                    route: '/s',
                    routeName: 's'),
                DashboardAction(
                    label: 'Admin overview',
                    icon: Icons.admin_panel_settings_outlined,
                    route: '/a',
                    routeName: 'a'),
              ],
              onOpen: (_) {},
            ),
            const SizedBox(height: 16),
            DashboardSearchBar(onTap: () {}),
          ]),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('empty states read well', (tester) async {
      await tester.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          AttentionCard(items: const [], onOpen: (_) {}),
          const SizedBox(height: 16),
          TodayCard(
              summary: DashboardSummary.empty,
              onOpenTask: (_) {},
              onOpenSchedule: () {}),
        ]),
      )));
      await tester.pump();

      expect(find.textContaining('All clear'), findsOneWidget);
      expect(find.text('Nothing scheduled today'), findsOneWidget);
    });

    testWidgets('tapping an attention row reports its route', (tester) async {
      String? opened;
      await tester.pumpWidget(host(AttentionCard(
        items: buildAttention(_inputs(DashboardAudience.field, daily: 1)),
        onOpen: (r) => opened = r,
      )));
      await tester.pump();

      await tester.tap(find.text('Daily vehicle check not done'));
      expect(opened, '/fleet/log');
    });

    testWidgets('the skeleton builds and animates', (tester) async {
      await tester.pumpWidget(host(const DashboardSkeleton()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('buildTechnicianDays', () {
    test('groups today by technician with count and next open time', () {
      final days = buildTechnicianDays([
        _task('a1', DateTime(2026, 11, 3, 15), assignee: 'u-ann'),
        _task('a2', DateTime(2026, 11, 3, 9),
            assignee: 'u-ann', status: 'completed'),
        _task('a3', DateTime(2026, 11, 3, 11), assignee: 'u-ann'),
        _task('b1', DateTime(2026, 11, 3, 8), assignee: 'u-bob'),
      ], now: _now, names: {'u-ann': 'Ann', 'u-bob': 'Bob'});

      expect(days.map((d) => d.name), ['Ann', 'Bob']);
      expect(days[0].count, 3);
      expect(days[0].openCount, 2);
      expect(days[0].nextTaskAt, DateTime(2026, 11, 3, 11));
      expect(days[1].nextTaskAt, DateTime(2026, 11, 3, 8));
    });

    test('ignores other days and cancelled tasks', () {
      final days = buildTechnicianDays([
        _task('y', DateTime(2026, 11, 2, 9), assignee: 'u-ann'),
        _task('t', DateTime(2026, 11, 4, 9), assignee: 'u-ann'),
        _task('c', DateTime(2026, 11, 3, 9),
            assignee: 'u-ann', status: 'cancelled'),
      ], now: _now);
      expect(days, isEmpty);
    });

    test('unassigned tasks form a last row; blank ids count as unassigned', () {
      final days = buildTechnicianDays([
        _task('u1', DateTime(2026, 11, 3, 10)),
        _task('u2', DateTime(2026, 11, 3, 12), assignee: '  '),
        _task('z', DateTime(2026, 11, 3, 9), assignee: 'u-zed'),
      ], now: _now, names: {'u-zed': 'Zed'});

      expect(days.map((d) => d.name), ['Zed', 'Unassigned']);
      expect(days.last.isUnassigned, isTrue);
      expect(days.last.count, 2);
    });

    test('roster technicians with no tasks appear with zero; unknown names '
        'fall back to a short id', () {
      final days = buildTechnicianDays([
        _task('x', DateTime(2026, 11, 3, 10), assignee: 'abcdef-1234'),
      ], now: _now, roster: ['u-idle'], names: {'u-idle': 'Idle'});

      expect(days.map((d) => d.name), ['Idle', 'Technician 1234']);
      expect(days.first.count, 0);
      expect(days.first.nextTaskAt, isNull);
    });

    test('a finished day has no next time', () {
      final days = buildTechnicianDays([
        _task('d', DateTime(2026, 11, 3, 9),
            assignee: 'u1', status: 'completed'),
      ], now: _now);
      expect(days.single.nextTaskAt, isNull);
    });
  });

  group('TechnicianDaysCard at 1.3x text', () {
    const sizes = {'phone': Size(360, 800), 'tablet': Size(1280, 800)};

    Widget host(Widget child) => MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: c!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    for (final entry in sizes.entries) {
      testWidgets('fits and reports taps on a ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final days = buildTechnicianDays([
          _task('1', DateTime(2026, 11, 3, 9), assignee: 'u1'),
          _task('2', DateTime(2026, 11, 3, 13), assignee: 'u1'),
          _task('3', DateTime(2026, 11, 3, 10)),
        ], now: _now, names: {
          'u1': 'Alexandria Montgomery-Featherstonehaugh',
        }, roster: [
          'u2'
        ]);

        TechnicianDay? opened;
        await tester.pumpWidget(host(Padding(
          padding: const EdgeInsets.all(16),
          child: TechnicianDaysCard(days: days, onOpen: (d) => opened = d),
        )));
        await tester.pump();

        expect(find.text('Who is on what today'), findsOneWidget);
        expect(find.text('Unassigned'), findsOneWidget);
        expect(find.text('2 tasks'), findsOneWidget);
        expect(find.text('Next at 9:00 AM'), findsOneWidget);

        await tester.tap(find.byKey(const Key('tech_day_u1')));
        expect(opened?.userId, 'u1');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(
          host(TechnicianDaysCard(days: const [], onOpen: (_) {})));
      await tester.pump();
      expect(find.text('No one is scheduled today'), findsOneWidget);
    });
  });
}
