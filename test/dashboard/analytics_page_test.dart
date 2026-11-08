import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_series.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_snapshot.dart';
import 'package:voltcore/modules/dashboard/presenter/analytics_providers.dart';
import 'package:voltcore/modules/dashboard/presenter/dashboard_providers.dart';
import 'package:voltcore/modules/dashboard/presenter/pages/analytics_page.dart';
import 'package:voltcore/modules/dashboard/presenter/widgets/analytics/analytics_chart_card.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/modules/work_orders/presenter/work_order_providers.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

// Sunday 8 Nov 2026, week of Monday 2 Nov.
final _now = DateTime(2026, 11, 8, 12);

Override _auth(UserRole role) => authStateProvider.overrideWith((ref) {
      final c = AuthController(ref, _FakeLogin(), _FakeLogout());
      c.state = AuthState(
        isAuthenticated: true,
        currentRole: role,
        userId: 'u1',
        displayName: 'Test',
      );
      return c;
    });

InspectionPoint _insp(DateTime d, String grade, String site) =>
    InspectionPoint(date: d, createdAt: d, grade: grade, siteCode: site);

/// 7 inspections: 3 this week, 1 last week, 2 in September, 1 in January.
/// 4 weeks: 4, 12 weeks: 6, all: 7. Red in 12 weeks: 3 (site A x2, site B x1).
final _full = AnalyticsSnapshot(
  inspections: [
    _insp(DateTime(2026, 11, 3), 'Red', 'SITE_A'),
    _insp(DateTime(2026, 11, 4), 'Red', 'SITE_A'),
    _insp(DateTime(2026, 11, 5), 'Green', 'SITE_C'),
    _insp(DateTime(2026, 10, 28), 'Amber', 'SITE_C'),
    _insp(DateTime(2026, 9, 10), 'Red', 'SITE_B'),
    _insp(DateTime(2026, 9, 11), 'Green', 'SITE_D'),
    _insp(DateTime(2026, 1, 12), 'Red', 'SITE_E'),
  ],
  maintenance: [
    MaintenancePoint(date: DateTime(2026, 11, 2), completed: true),
    MaintenancePoint(date: DateTime(2026, 10, 15), completed: true),
    MaintenancePoint(date: DateTime(2026, 11, 3), completed: false),
    MaintenancePoint(date: DateTime(2026, 1, 3), completed: true),
  ],
  tasks: [
    TaskPoint(when: DateTime(2026, 11, 3), status: 'scheduled', assignee: 'u1'),
    TaskPoint(when: DateTime(2026, 11, 4), status: 'scheduled', assignee: 'u1'),
    TaskPoint(when: DateTime(2026, 11, 5), status: 'scheduled', assignee: 'u2'),
    TaskPoint(when: DateTime(2026, 11, 6), status: 'scheduled'),
  ],
);

WorkOrderEntity _order(String id, WorkOrderStatus s, DateTime? at, {String? who}) =>
    WorkOrderEntity(
      id: id,
      tenantId: 't',
      title: id,
      status: s,
      priority: WorkOrderPriority.normal,
      assignedToUserId: who,
      scheduledFor: at,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

final _orders = [
  _order('a', WorkOrderStatus.scheduled, DateTime(2026, 11, 1), who: 'u1'), // overdue
  _order('b', WorkOrderStatus.inProgress, DateTime(2026, 11, 8), who: 'u2'),
  _order('c', WorkOrderStatus.completed, DateTime(2026, 10, 1), who: 'u1'),
  _order('d', WorkOrderStatus.draft, null),
];

StockLevel _level(String id, int onHand, {int min = 2}) => StockLevel(
      part: CatalogPart(
        id: id,
        partNumber: id,
        minStock: min,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      onHand: onHand,
      reserved: 0,
    );

final _levels = [_level('p1', 10), _level('p2', 1), _level('p3', 0)];

final List<FlutterErrorDetails> _overflows = [];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AnalyticsSnapshot snapshot = const AnalyticsSnapshot(),
  UserRole role = UserRole.admin,
  List<WorkOrderEntity> orders = const [],
  List<StockLevel> levels = const [],
  Size size = const Size(390, 6000),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
  GoRouter? router,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    _auth(role),
    analyticsSnapshotLoaderProvider.overrideWithValue(() => snapshot),
    analyticsClockProvider.overrideWithValue(() => _now),
    workOrderListProvider.overrideWith((ref) async => orders),
    stockLevelsProvider.overrideWith((ref) async => levels),
    dashboardTechniciansProvider.overrideWith((ref) async => (
          names: {'u1': 'Ana', 'u2': 'Ben', 'u3': 'Cy'},
          roster: ['u1', 'u2', 'u3'],
        )),
  ]);
  addTearDown(container.dispose);

  final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  Widget builder(BuildContext c, Widget? child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: router == null
        ? MaterialApp(theme: theme, builder: builder, home: const AnalyticsPage())
        : MaterialApp.router(theme: theme, builder: builder, routerConfig: router),
  ));
  await _settle(tester);
  return container;
}

/// The page has an animating sync indicator, so no pumpAndSettle.
Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _sem(String startsWith) =>
    find.bySemanticsLabel(RegExp('^${RegExp.escape(startsWith)}'));

void main() {
  late void Function(FlutterErrorDetails)? oldHandler;
  setUp(() {
    _overflows.clear();
    oldHandler = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        _overflows.add(d);
      } else {
        oldHandler?.call(d);
      }
    };
  });
  tearDown(() => FlutterError.onError = oldHandler);

  group('every chart reads out its numbers', () {
    testWidgets('admin with data', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, snapshot: _full, orders: _orders, levels: _levels);

      expect(_sem('Inspections per week, 12 weeks: 6 total'), findsOneWidget);
      expect(_sem('Inspections per month, 6 months: 6 total'), findsOneWidget);
      expect(_sem('Site grades: 6 inspections. 2 green, 1 amber, 3 red, 0 ungraded'),
          findsOneWidget);
      expect(
          _sem('Red-grade inspections by site, top 2: SITE_A 2, SITE_B 1. 3 total'),
          findsOneWidget);
      expect(
          _sem('Jobs by status: 4 total. Draft 1, Scheduled 1, In progress 1, '
              'Completed 1, Cancelled 0'),
          findsOneWidget);
      expect(_sem('Open jobs: 3. 2 on time, 1 overdue'), findsOneWidget);
      expect(_sem('Maintenance records completed per month, 6 months: 2 total'),
          findsOneWidget);
      expect(_sem('Maintenance records: 3. 2 completed, 1 in progress'), findsOneWidget);
      expect(
          _sem('Tasks per technician this week: 4 total. Ana 2, Ben 1, Unassigned 1, Cy 0'),
          findsOneWidget);
      expect(_sem('Parts: 3. 1 in stock, 1 low, 1 out of stock'), findsOneWidget);

      // The existing numbers are still there.
      expect(find.text('Total inspections'), findsOneWidget);
      expect(find.text('Maintenance completion'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('6 total'), findsWidgets);
      handle.dispose();
      expect(_overflows, isEmpty);
    });

    testWidgets('empty data shows "Not enough data yet" on every chart', (tester) async {
      await _pump(tester);
      // weekly, monthly, grades, top sites, maintenance, jobs, workload, parts
      expect(find.text(kNotEnoughData), findsNWidgets(8));
      expect(find.text('0 total'), findsNWidgets(8));
      expect(_overflows, isEmpty);
    });
  });

  group('period selector', () {
    testWidgets('changes the series and is remembered for the session', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await _pump(tester, snapshot: _full, orders: _orders, levels: _levels);
      expect(c.read(analyticsPeriodProvider), AnalyticsPeriod.weeks12);

      await tester.tap(find.byKey(const Key('period-weeks4')));
      await _settle(tester, 3);
      expect(_sem('Inspections per week, 4 weeks: 4 total'), findsOneWidget);
      expect(_sem('Site grades: 4 inspections'), findsOneWidget);
      expect(_sem('Red-grade inspections by site, top 1: SITE_A 2. 2 total'), findsOneWidget);
      expect(c.read(analyticsPeriodProvider), AnalyticsPeriod.weeks4);

      await tester.tap(find.byKey(const Key('period-all')));
      await _settle(tester, 3);
      // January 12 is 43 weeks back (Monday 5 Jan to Monday 2 Nov, inclusive).
      expect(_sem('Inspections per week, 43 weeks: 7 total'), findsOneWidget);
      expect(_sem('Site grades: 7 inspections'), findsOneWidget);
      expect(_sem('Maintenance records: 4. 3 completed, 1 in progress'), findsOneWidget);
      expect(_sem('Inspections per month, 11 months: 7 total'), findsOneWidget);

      // Open the page again in the same container: the choice is kept.
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AnalyticsPage()),
      ));
      await _settle(tester);
      expect(c.read(analyticsPeriodProvider), AnalyticsPeriod.all);
      expect(_sem('Inspections per week, 43 weeks: 7 total'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('full labels on a wide screen', (tester) async {
      await _pump(tester, size: const Size(1280, 3000));
      expect(find.text('12 weeks'), findsOneWidget);
      expect(find.text('6 months'), findsOneWidget);
    });
  });

  group('role gating', () {
    testWidgets('technician sees no workload or parts chart, and only own jobs',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester,
          snapshot: _full, role: UserRole.tech, orders: _orders, levels: _levels);
      expect(find.text('Technician workload'), findsNothing);
      expect(find.text('Parts stock'), findsNothing);
      // u1 owns two of the four jobs: scheduled (overdue) and completed.
      expect(find.text('Jobs by status'), findsOneWidget);
      expect(_sem('Jobs by status: 2 total'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('supervisor sees parts but not workload', (tester) async {
      await _pump(tester, snapshot: _full, role: UserRole.supervisor, levels: _levels);
      expect(find.text('Parts stock'), findsOneWidget);
      expect(find.text('Technician workload'), findsNothing);
    });

    testWidgets('dispatcher sees workload and parts', (tester) async {
      await _pump(tester, snapshot: _full, role: UserRole.dispatcher, levels: _levels);
      expect(find.text('Parts stock'), findsOneWidget);
      expect(find.text('Technician workload'), findsOneWidget);
    });
  });

  group('interaction', () {
    testWidgets('tapping a bar shows that week in the readout', (tester) async {
      await _pump(tester, snapshot: _full);
      final readout = find.byKey(const Key('chart-readout')).first;
      expect((tester.widget(readout) as Text).data, 'Week of 2 Nov: 3 inspections');

      final chart = find.byType(TimeSeriesChart).first;
      final topLeft = tester.getTopLeft(chart);
      await tester.tapAt(topLeft + const Offset(4, 60)); // first of 12 bars
      await tester.pump();
      expect((tester.widget(readout) as Text).data, 'Week of 17 Aug: 0 inspections');

      await tester.tapAt(topLeft + Offset(tester.getSize(chart).width - 4, 60));
      await tester.pump();
      expect((tester.widget(readout) as Text).data, 'Week of 2 Nov: 3 inspections');
    });

    testWidgets('a grade row opens the inspections list for that grade', (tester) async {
      String? seen;
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const AnalyticsPage()),
        GoRoute(
          path: '/inspections',
          builder: (_, state) {
            seen = state.uri.queryParameters['grade'];
            return const Scaffold(body: Text('inspection list'));
          },
        ),
      ]);
      await _pump(tester, snapshot: _full, router: router);
      await tester.tap(find.text('Red'));
      await _settle(tester, 4);
      expect(find.text('inspection list'), findsOneWidget);
      expect(seen, 'red');
    });
  });

  group('no overflow at 1.3x text', () {
    const sizes = <String, Size>{
      'phone 360x800': Size(360, 800),
      'tablet portrait 800x1280': Size(800, 1280),
      'tablet landscape 1280x800': Size(1280, 800),
    };
    for (final dark in [false, true]) {
      for (final e in sizes.entries) {
        testWidgets('${e.key}, ${dark ? 'dark' : 'light'}', (tester) async {
          await _pump(
            tester,
            snapshot: _full,
            orders: _orders,
            levels: _levels,
            size: e.value,
            textScale: 1.3,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          for (var i = 0; i < 14; i++) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
            await _settle(tester, 2);
          }
          expect(_overflows, isEmpty,
              reason: _overflows.map((d) => d.exceptionAsString()).join('\n'));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
