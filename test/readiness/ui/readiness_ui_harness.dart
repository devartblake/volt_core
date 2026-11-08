import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/readiness/domain/readiness_export_data.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/presenter/pages/readiness_page.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_providers.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_services.dart';

import '../readiness_fixtures.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class MemStore implements ReadinessConfigStore {
  MemStore([this.config = const ReadinessConfig()]);
  ReadinessConfig config;
  @override
  ReadinessConfig load() => config;
  @override
  Future<void> save(ReadinessConfig c) async => config = c;
}

/// Records what was asked; fails for the titles in [failFor].
class FakeScheduler extends ReadinessScheduler {
  FakeScheduler({this.failFor = const {}});
  final Set<String> failFor;
  final calls = <(String, DateTime)>[];
  int reloads = 0;

  @override
  Future<void> scheduleInspection(ReadinessUnit unit, DateTime date) async {
    if (failFor.contains(unit.serial)) throw StateError('boom');
    calls.add((unit.serial, date));
  }

  @override
  Future<void> reload() async => reloads++;
}

class FakeExporter extends ReadinessExporter {
  FakeExporter({this.csv, this.pdf});

  /// null = completes, false = cancelled, an Object = throws.
  final Object? csv;
  final Object? pdf;
  final csvCalls = <List<ReadinessUnit>>[];
  final pdfCalls = <ReadinessExportData>[];

  Future<bool> _go(Object? mode) async {
    if (mode == false) return false;
    if (mode is Exception || mode is Error) throw mode!;
    return true;
  }

  @override
  Future<bool> shareCsv(List<ReadinessUnit> units) {
    csvCalls.add(units);
    return _go(csv);
  }

  @override
  Future<bool> sharePdf(ReadinessExportData data) {
    pdfCalls.add(data);
    return _go(pdf);
  }
}

/// 12 generators covering every status. As of [kNow] (Sat 7 Nov 2026) with the
/// default thresholds:
///  * Not ready  (2): S1 red grade, S2 overdue 45 days
///  * Attention  (2): S3 overdue 10 days (+3 parts short), S4 amber (+follow-up)
///  * Due soon   (3): S5 in 5 days, S6 in 20, S7 in 9
///  * Ready      (5): S8..S12
/// So 5 of 12 = 42% ready; 2 overdue.
ReadinessInputs fleetInputs() => ReadinessInputs(
      inspections: [
        insp('i1', serial: 'S1', site: 'Q_001', make: 'Kohler', model: '250REOZD', grade: 'Red', ago: 20, dueIn: 40),
        insp('i2', serial: 'S2', site: 'Q_002', make: 'Generac', model: 'RG', ago: 400, dueIn: -45),
        insp('i3', serial: 'S3', site: 'X_003', make: 'Cat', model: 'C9', ago: 375, dueIn: -10),
        insp('i4', serial: 'S4', site: 'X_004', make: 'Cummins', model: 'C60', grade: 'Amber', ago: 30, dueIn: 100),
        insp('i5', serial: 'S5', site: 'Q_005', make: 'Kohler', model: '100', ago: 340, dueIn: 5),
        insp('i6', serial: 'S6', site: 'Q_006', make: 'Generac', model: 'RG', ago: 340, dueIn: 20),
        insp('i7', serial: 'S7', site: 'X_007', make: 'Cat', model: 'C9', ago: 340, dueIn: 9),
        insp('i8', serial: 'S8', site: 'Q_008', make: 'Kohler', model: '100', ago: 10, dueIn: 60),
        insp('i9', serial: 'S9', site: 'Q_009', make: 'Generac', model: 'RG', ago: 10, dueIn: 90),
        insp('i10', serial: 'S10', site: 'X_010', make: 'Cat', model: 'C9', ago: 10, dueIn: 120),
        insp('i11', serial: 'S11', site: 'Q_011', make: 'Cummins', model: 'C60', ago: 10, dueIn: 200),
        insp('i12', serial: 'S12', site: 'Q_012', make: 'Kohler', model: '100', ago: 10, dueIn: 300),
      ],
      maintenance: [
        ReadinessMaintenance(
          id: 'm4',
          inspectionId: 'i4',
          serial: 'S4',
          date: day(-5),
          requiresFollowUp: true,
          followUpNotes: 'Replace transfer switch relay',
        ),
      ],
      jobNeeds: [
        const ReadinessJobNeed(
            type: ReadinessJobType.inspection, jobId: 'i3', shortCount: 3),
      ],
    );

/// [n] ready generators, for laziness checks.
ReadinessInputs manyInputs(int n) => ReadinessInputs(inspections: [
      for (var i = 0; i < n; i++)
        insp('m$i', serial: 'M$i', site: 'Q_${100 + i}', ago: 10, dueIn: 60 + i),
    ]);

Override authAs(UserRole role) => authStateProvider.overrideWith((ref) {
      final c = AuthController(ref, _FakeLogin(), _FakeLogout());
      c.state = AuthState(
        isAuthenticated: true,
        currentRole: role,
        userId: 'u1',
        displayName: 'Test',
      );
      return c;
    });

/// Overflow errors raised while pumping.
final List<FlutterErrorDetails> overflows = [];

void captureOverflows() {
  late void Function(FlutterErrorDetails)? old;
  setUp(() {
    overflows.clear();
    old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        overflows.add(d);
      } else {
        old?.call(d);
      }
    };
  });
  tearDown(() => FlutterError.onError = old);
}

/// Pumps the page with in-memory data; never touches Hive or Supabase.
Future<ProviderContainer> pumpReadiness(
  WidgetTester tester, {
  Size size = const Size(390, 2600),
  UserRole role = UserRole.admin,
  ReadinessInputs? inputs,
  Object? inputsError,
  FutureOr<ReadinessInputs> Function()? source,
  Future<ReadinessInputs>? pending,
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
  ReadinessScheduler? scheduler,
  ReadinessExporter? exporter,
  MemStore? store,
  String? initialStatus,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final data = inputs ?? fleetInputs();
  final container = ProviderContainer(overrides: [
    authAs(role),
    readinessClockProvider.overrideWithValue(() => kNow),
    readinessConfigStoreProvider.overrideWithValue(store ?? MemStore()),
    readinessInputsProvider.overrideWith((ref) {
      if (source != null) return source();
      if (pending != null) return pending;
      if (inputsError != null) throw inputsError;
      return data;
    }),
    readinessSchedulerProvider.overrideWithValue(scheduler ?? FakeScheduler()),
    readinessExporterProvider.overrideWithValue(exporter ?? FakeExporter()),
    ...extra,
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ReadinessPage(initialStatus: initialStatus),
    ),
  ));
  await settle(tester);
  return container;
}

/// The page has an animating sync indicator, so no pumpAndSettle.
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The key of the unit with this serial.
String unitKey(ProviderContainer c, String serial) =>
    c.read(readinessUnitsProvider).value!.firstWhere((u) => u.serial == serial).key;

/// Scrolls the page list until [finder] is on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300,
      scrollable: find.byType(Scrollable).first);
  await settle(tester, 2);
}

/// Taps [finder] after scrolling it into view (inside sheets and the
/// horizontally scrolling segment bar).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester, 2);
}
