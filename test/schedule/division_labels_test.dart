import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/admin/infra/division_repository.dart';
import 'package:voltcore/modules/dashboard/domain/technician_day.dart';
import 'package:voltcore/modules/dashboard/presenter/dashboard_providers.dart';
import 'package:voltcore/modules/dashboard/presenter/widgets/dashboard_sections.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/assign_technician_sheet.dart';

const _long =
    'Generators, Fire alarm, Lighting controls, Emergency power, Transfer switches, Switchgear';

TaskScheduleEntity _task() => TaskScheduleEntity(
      id: 't1',
      scheduledAt: DateTime(2026, 11, 3, 9),
      scheduledDate: DateTime(2026, 11, 3),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      title: 'Morning check',
      sourceType: 'manual',
      siteCode: 'S-1',
      status: 'scheduled',
    );

const _sizes = {'phone': Size(360, 800), 'tablet': Size(1280, 800)};

Widget _sheetApp(
  Future<Map<String, String>> Function() labels,
  ThemeMode mode,
) =>
    ProviderScope(
      overrides: [
        dashboardTechniciansProvider.overrideWith((ref) async => (
              names: {'u1': 'Ana Rivera', 'u2': 'Bo Chen'},
              roster: ['u1', 'u2'],
            )),
        teamDivisionLabelsProvider.overrideWith((ref) => labels()),
      ],
      child: MaterialApp(
        themeMode: mode,
        theme: ThemeData(extensions: const [StatusColors.light]),
        darkTheme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [StatusColors.dark]),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: c!,
        ),
        home: Scaffold(body: AssignTechnicianSheet(task: _task())),
      ),
    );

void main() {
  group('Assign technician sheet division labels', () {
    for (final size in _sizes.entries) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('shows labels, no overflow: ${size.key} ${mode.name}',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_sheetApp(
              () async => {'u1': 'Generators, Fire alarm', 'u2': _long}, mode));
          await tester.pump();
          await tester.pump();

          expect(find.text('Ana Rivera'), findsOneWidget);
          expect(find.text('Generators, Fire alarm'), findsOneWidget);
          expect(find.byKey(const Key('assign_divisions_u2')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('shows nothing and no error when divisions are unavailable',
        (tester) async {
      await tester.pumpWidget(_sheetApp(() async => const {}, ThemeMode.light));
      await tester.pump();
      await tester.pump();
      expect(find.text('Ana Rivera'), findsOneWidget);
      expect(find.byKey(const Key('assign_divisions_u1')), findsNothing);
      expect(find.text('Could not load technicians.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing labels provider does not break the sheet',
        (tester) async {
      await tester
          .pumpWidget(_sheetApp(() async => throw Exception('x'), ThemeMode.light));
      await tester.pump();
      await tester.pump();
      expect(find.text('Bo Chen'), findsOneWidget);
      expect(find.byKey(const Key('assign_divisions_u2')), findsNothing);
    });
  });

  group('TechnicianDaysCard division labels', () {
    for (final size in _sizes.entries) {
      testWidgets('fits at 1.3x on ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final days = [
          const TechnicianDay(
              userId: 'u1', name: 'Ana Rivera', tasks: [], nextTaskAt: null),
          const TechnicianDay(
              userId: 'u2', name: 'Bo Chen', tasks: [], nextTaskAt: null),
        ];
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: c!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TechnicianDaysCard(
                days: days,
                onOpen: (_) {},
                divisionLabels: const {'u1': 'Generators', 'u2': _long},
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(find.text('Generators'), findsOneWidget);
        expect(find.byKey(const Key('tech_day_divisions_u2')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
