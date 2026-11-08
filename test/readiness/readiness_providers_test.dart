import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';
import 'package:voltcore/modules/readiness/presenter/readiness_providers.dart';

import 'readiness_fixtures.dart';

class FakeStore implements ReadinessConfigStore {
  FakeStore([this.config = const ReadinessConfig()]);

  ReadinessConfig config;
  int saves = 0;

  @override
  ReadinessConfig load() => config;

  @override
  Future<void> save(ReadinessConfig c) async {
    saves++;
    config = c;
  }
}

/// [n] generators spread over sites, grades and due dates.
ReadinessInputs generated(int n) {
  final grades = ['Green', 'Green', 'Amber', 'Red', ''];
  final makes = ['Kohler', 'Generac', 'Cat', 'Cummins'];
  return ReadinessInputs(
    inspections: [
      for (var i = 0; i < n; i++)
        insp('i$i',
            serial: 'SN$i',
            site: i % 2 == 0 ? 'Q_${i % 40}' : 'X_${i % 40}',
            make: makes[i % makes.length],
            model: 'M${i % 9}',
            grade: grades[i % grades.length],
            ago: 5 + i % 300,
            dueIn: i % 7 == 0 ? null : (i * 11) % 200 - 60,
            load: i % 3 == 0),
    ],
    maintenance: [
      for (var i = 0; i < n; i += 4)
        ReadinessMaintenance(
            id: 'm$i',
            serial: 'SN$i',
            date: day(-(i % 50)),
            requiresFollowUp: true,
            followUpNotes: 'Note $i'),
    ],
    tasks: [
      for (var i = 0; i < n; i += 3)
        ReadinessTask(
            id: 't$i',
            scheduledAt: day(i % 60 - 10),
            inspectionId: 'i$i'),
    ],
    equipment: [
      for (var i = 0; i < n; i++)
        ReadinessEquipment(id: 'e$i', serial: 'SN$i', siteCode: 'Q_${i % 40}'),
    ],
    sites: [
      for (var s = 0; s < 40; s++)
        ReadinessSite(siteCode: 'Q_$s', address: '$s Main', customerName: 'Cust ${s % 5}'),
    ],
    jobNeeds: [
      for (var i = 0; i < n; i += 5)
        ReadinessJobNeed(
            type: ReadinessJobType.inspection, jobId: 'i$i', shortCount: 1),
    ],
  );
}

ProviderContainer make(ReadinessInputs inputs,
    {FakeStore? store, List<Override> extra = const []}) {
  final c = ProviderContainer(overrides: [
    readinessInputsProvider.overrideWith((ref) async => inputs),
    readinessConfigStoreProvider.overrideWithValue(store ?? FakeStore()),
    readinessClockProvider.overrideWithValue(() => kNow),
    ...extra,
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('config', () {
    test('loads defaults from the store', () {
      final c = make(const ReadinessInputs());
      expect(c.read(readinessConfigProvider), const ReadinessConfig());
    });

    test('loads saved thresholds', () {
      final c = make(const ReadinessInputs(),
          store: FakeStore(const ReadinessConfig(dueSoonDays: 14, criticalOverdueDays: 7)));
      final cfg = c.read(readinessConfigProvider);
      expect(cfg.dueSoonDays, 14);
      expect(cfg.criticalOverdueDays, 7);
    });

    test('only an admin can change it', () async {
      final store = FakeStore();
      final c = make(const ReadinessInputs(), store: store);
      final ctl = c.read(readinessConfigProvider.notifier);
      for (final role in [UserRole.tech, UserRole.supervisor, UserRole.dispatcher, null]) {
        expect(await ctl.update(const ReadinessConfig(dueSoonDays: 5), role: role), isFalse);
      }
      expect(store.saves, 0);
      expect(c.read(readinessConfigProvider).dueSoonDays, 30);
      expect(await ctl.update(const ReadinessConfig(dueSoonDays: 5), role: UserRole.admin),
          isTrue);
      expect(store.saves, 1);
      expect(store.config.dueSoonDays, 5);
      expect(c.read(readinessConfigProvider).dueSoonDays, 5);
    });

    test('values are clamped to 0..3650', () async {
      final c = make(const ReadinessInputs());
      await c.read(readinessConfigProvider.notifier).update(
          const ReadinessConfig(dueSoonDays: -4, criticalOverdueDays: 99999),
          role: UserRole.admin);
      expect(c.read(readinessConfigProvider).dueSoonDays, 0);
      expect(c.read(readinessConfigProvider).criticalOverdueDays, 3650);
    });

    test('the preferences store falls back to defaults when no box is open', () {
      final cfg = const PreferencesReadinessConfigStore().load();
      expect(cfg.dueSoonDays, 30);
      expect(cfg.criticalOverdueDays, 30);
    });

    test('changing thresholds recomputes the units', () async {
      final inputs = ReadinessInputs(inspections: [insp('a', dueIn: 20)]);
      final c = make(inputs);
      c.listen(readinessUnitsProvider, (_, __) {});
      await c.read(readinessReportProvider.future);
      expect(c.read(readinessUnitsProvider).value!.single.status, ReadinessStatus.dueSoon);
      await c.read(readinessConfigProvider.notifier).update(
          const ReadinessConfig(dueSoonDays: 10), role: UserRole.admin);
      await c.read(readinessReportProvider.future);
      expect(c.read(readinessUnitsProvider).value!.single.status, ReadinessStatus.ready);
    });
  });

  group('providers', () {
    test('units and summary come from the inputs', () async {
      final c = make(generated(120));
      c.listen(readinessSummaryProvider, (_, __) {});
      final report = await c.read(readinessReportProvider.future);
      expect(report.units, hasLength(120));
      expect(report.now, kNow);

      final units = c.read(readinessUnitsProvider).value!;
      expect(units, same(report.units));
      final summary = c.read(readinessSummaryProvider).value!;
      expect(summary.total, 120);
      expect(
          ReadinessStatus.values.fold<int>(0, (a, s) => a + summary.count(s)), 120);
      expect(summary.worstUnits.length, 5);
      expect(summary.dueByWeek, hasLength(12));
    });

    test('loading and error states pass through', () async {
      final c = ProviderContainer(overrides: [
        readinessInputsProvider.overrideWith((ref) async => throw StateError('boom')),
        readinessConfigStoreProvider.overrideWithValue(FakeStore()),
      ]);
      addTearDown(c.dispose);
      c.listen(readinessUnitsProvider, (_, __) {});
      expect(c.read(readinessUnitsProvider).isLoading, isTrue);
      await expectLater(c.read(readinessReportProvider.future), throwsStateError);
      expect(c.read(readinessUnitsProvider).hasError, isTrue);
      expect(c.read(readinessSummaryProvider).hasError, isTrue);
    });

    test('filter and sort do not recompute the report', () async {
      var builds = 0;
      final c = ProviderContainer(overrides: [
        readinessInputsProvider.overrideWith((ref) async {
          builds++;
          return generated(100);
        }),
        readinessConfigStoreProvider.overrideWithValue(FakeStore()),
        readinessClockProvider.overrideWithValue(() => kNow),
      ]);
      addTearDown(c.dispose);
      c.listen(filteredReadinessUnitsProvider, (_, __) {});
      await c.read(readinessReportProvider.future);
      final before = c.read(readinessReportProvider).value;

      c.read(readinessFilterProvider.notifier).state =
          const ReadinessFilter(statuses: {ReadinessStatus.notReady});
      c.read(readinessSortProvider.notifier).state = ReadinessSort.title;

      final shown = c.read(filteredReadinessUnitsProvider).value!;
      expect(shown, isNotEmpty);
      expect(shown.every((u) => u.status == ReadinessStatus.notReady), isTrue);
      final titles = shown.map((u) => u.title.toLowerCase()).toList();
      expect(titles, [...titles]..sort());
      expect(builds, 1);
      expect(c.read(readinessReportProvider).value, same(before));
    });

    test('filtered list reacts to the text query', () async {
      final c = make(generated(100));
      c.listen(filteredReadinessUnitsProvider, (_, __) {});
      await c.read(readinessReportProvider.future);
      c.read(readinessFilterProvider.notifier).state =
          const ReadinessFilter(query: 'sn42');
      final shown = c.read(filteredReadinessUnitsProvider).value!;
      expect(shown.map((u) => u.serial), ['SN42']);
    });

    test('filter and sort start empty / worst first', () {
      final c = make(const ReadinessInputs());
      expect(c.read(readinessFilterProvider).isEmpty, isTrue);
      expect(c.read(readinessSortProvider), ReadinessSort.worstFirst);
    });

    test('units are worst first by default', () async {
      final c = make(generated(150));
      c.listen(filteredReadinessUnitsProvider, (_, __) {});
      await c.read(readinessReportProvider.future);
      final units = c.read(filteredReadinessUnitsProvider).value!;
      for (var i = 1; i < units.length; i++) {
        expect(units[i - 1].status.rank <= units[i].status.rank, isTrue);
      }
    });

    test('an empty fleet gives an empty list and a zero summary', () async {
      final c = make(const ReadinessInputs());
      c.listen(readinessSummaryProvider, (_, __) {});
      await c.read(readinessReportProvider.future);
      expect(c.read(readinessUnitsProvider).value, isEmpty);
      expect(c.read(readinessSummaryProvider).value!.percentReady, 0.0);
    });
  });

  group('performance', () {
    test('500 units compute in well under 200 ms', () {
      final inputs = generated(500);
      computeReadiness(inputs, const ReadinessConfig(), kNow); // warm up
      final sw = Stopwatch()..start();
      final r = computeReadiness(inputs, const ReadinessConfig(), kNow);
      final s = summarizeReadiness(r.units, kNow);
      sw.stop();
      expect(r.units, hasLength(500));
      expect(s.total, 500);
      // ignore: avoid_print
      print('500 units: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(200));
    });

    test('5000 units still finish quickly (no quadratic join)', () {
      final inputs = generated(5000);
      final sw = Stopwatch()..start();
      computeReadiness(inputs, const ReadinessConfig(), kNow);
      sw.stop();
      // ignore: avoid_print
      print('5000 units: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
