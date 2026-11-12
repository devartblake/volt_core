import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_filter_preset.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/sign_off_access.dart';
import 'package:voltcore/modules/inspections/domain/inspection_completion.dart';
import 'package:voltcore/modules/inspections/domain/inspection_unanswered.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/inspections/infra/repositories/inspection_repository.dart';
import 'package:voltcore/modules/inspections/infra/repositories/inspection_repository_impl.dart';
import 'package:voltcore/modules/inspections/presenter/controllers/inspection_list_prefs.dart';
import 'package:voltcore/modules/inspections/presenter/controllers/user_profile_controller.dart';
import 'package:voltcore/modules/inspections/presenter/pages/inspection_list_page.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/finish_sheet.dart';

class _NoParts extends MaterialsRepository {
  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async => const [];
}

class _FakeRepo implements InspectionRepository {
  _FakeRepo(this.items);
  final List<InspectionEntity> items;
  final deleted = <String>[];

  @override
  Future<List<InspectionEntity>> listInspections() async =>
      items.where((i) => !deleted.contains(i.id)).toList();

  @override
  Future<void> deleteInspection(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _FakePrefs implements InspectionListPrefs {
  List<InspectionFilterPreset> presets = [];
  InspectionDensity density = InspectionDensity.comfortable;
  @override
  List<InspectionFilterPreset> loadPresets() => presets;
  @override
  Future<void> savePresets(List<InspectionFilterPreset> p) async => presets = p;
  @override
  InspectionDensity loadDensity() => density;
  @override
  Future<void> saveDensity(InspectionDensity d) async => density = d;
}

InspectionEntity _ins(String site, String grade, {String address = ''}) =>
    InspectionEntity.newDraft().copyWith(
        siteCode: site,
        siteGrade: grade,
        address: address.isEmpty ? '$site Street' : address);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepo repo,
  _FakePrefs prefs, {
  bool canDelete = true,
  bool canSignOff = true,
  double scale = 1.0,
  Size size = const Size(400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      inspectionRepositoryProvider.overrideWithValue(repo),
      inspectionListPrefsProvider.overrideWithValue(prefs),
      inspectionCanDeleteProvider.overrideWithValue(canDelete),
      canSignOffProvider.overrideWithValue(canSignOff),
      materialsRepositoryProvider.overrideWithValue(_NoParts()),
      currentTenantProvider.overrideWith((ref) =>
          TenantNotifier(availableTenants: const ['T'], initialTenant: 'T')),
    ],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const InspectionListPage(),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The inspection rows (the snackbar is a Dismissible too).
final _rows = find.byWidgetPredicate((w) =>
    w is Dismissible &&
    w.key is ValueKey &&
    ((w.key as ValueKey).value as String).startsWith('inspection-'));

void main() {
  late List<Object> errors;
  void Function(FlutterErrorDetails)? oldHandler;
  setUp(() {
    errors = [];
    oldHandler = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) errors.add(d);
    };
  });
  tearDown(() => FlutterError.onError = oldHandler);

  testWidgets('grade chip narrows the list; saving makes a preset chip',
      (tester) async {
    final repo = _FakeRepo([_ins('AAA', 'Green'), _ins('BBB', 'Red')]);
    final prefs = _FakePrefs();
    await _pump(tester, repo, prefs);
    expect(find.textContaining('AAA Street'), findsOneWidget);
    expect(find.textContaining('BBB Street'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Red'));
    await tester.pump();
    expect(find.textContaining('AAA Street'), findsNothing);
    expect(find.textContaining('BBB Street'), findsOneWidget);

    await tester.tap(find.text('Save filter'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, 'Reds');
    await tester.tap(find.text('Save').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(prefs.presets.single.name, 'Reds');
    expect(find.widgetWithText(ChoiceChip, 'Reds'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Needs follow-up'));
    await tester.pump();
    expect(find.textContaining('BBB Street'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('density toggle is remembered', (tester) async {
    final prefs = _FakePrefs();
    await _pump(tester, _FakeRepo([_ins('AAA', 'Green')]), prefs);
    await tester.tap(find.byTooltip('Compact rows'));
    await tester.pump();
    expect(prefs.density, InspectionDensity.compact);
    expect(find.byTooltip('Comfortable rows'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('swipe left hides the row, Undo restores, no delete happens',
      (tester) async {
    final repo = _FakeRepo([_ins('AAA', 'Green'), _ins('BBB', 'Red')]);
    await _pump(tester, repo, _FakePrefs());
    await tester.drag(find.textContaining('AAA Street'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_rows, findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_rows, findsNWidgets(2));
    await tester.pump(const Duration(seconds: 7));
    expect(repo.deleted, isEmpty);
  });

  testWidgets('swipe left without Undo deletes after the window',
      (tester) async {
    final repo = _FakeRepo([_ins('AAA', 'Green'), _ins('BBB', 'Red')]);
    await _pump(tester, repo, _FakePrefs());
    await tester.drag(find.textContaining('AAA Street'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.deleted, isEmpty);
    await tester.pump(const Duration(seconds: 7));
    expect(repo.deleted, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(_rows, findsOneWidget);
  });

  testWidgets('without delete permission a left swipe does nothing',
      (tester) async {
    final repo = _FakeRepo([_ins('AAA', 'Green')]);
    await _pump(tester, repo, _FakePrefs(), canDelete: false);
    await tester.drag(find.textContaining('AAA Street'), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('AAA Street'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('an apprentice swiping to delete is told who can, nothing is deleted',
      (tester) async {
    final repo = _FakeRepo([_ins('AAA', 'Green')]);
    await _pump(tester, repo, _FakePrefs(), canDelete: false, canSignOff: false);
    await tester.drag(find.textContaining('AAA Street'), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A technician or supervisor needs to sign this off.'),
        findsOneWidget);
    expect(find.textContaining('AAA Street'), findsOneWidget);
    expect(repo.deleted, isEmpty);
  });

  test('the delete rule excludes apprentices and technicians', () {
    expect(roleCanDeleteInspection(UserRole.apprentice), isFalse);
    expect(roleCanDeleteInspection(UserRole.tech), isFalse);
    expect(roleCanDeleteInspection(UserRole.admin), isTrue);
    expect(roleCanDeleteInspection(UserRole.dispatcher), isTrue);
  });

  for (final c in {
    'phone 1.3x': (const Size(360, 740), 1.3),
    'tablet 1.3x': (const Size(1000, 700), 1.3),
  }.entries) {
    testWidgets('no overflow: ${c.key}', (tester) async {
      final prefs = _FakePrefs()..density = InspectionDensity.compact;
      prefs.presets = [
        const InspectionFilterPreset(id: '1', name: 'A rather long preset name'),
      ];
      await _pump(
        tester,
        _FakeRepo([
          _ins('AAA', 'Green',
              address: 'A very long street address indeed 12345'),
          _ins('BBB', 'Red'),
        ]),
        prefs,
        size: c.value.$1,
        scale: c.value.$2,
      );
      expect(errors, isEmpty);
      await tester.tap(find.byTooltip('Comfortable rows'));
      await tester.pump();
      expect(errors, isEmpty);
    });
  }

  test('delete roles: admin and dispatcher only', () {
    expect(roleCanDeleteInspection(UserRole.admin), isTrue);
    expect(roleCanDeleteInspection(UserRole.dispatcher), isTrue);
    expect(roleCanDeleteInspection(UserRole.supervisor), isFalse);
    expect(roleCanDeleteInspection(UserRole.tech), isFalse);
    expect(roleCanDeleteInspection(null), isFalse);
  });

  testWidgets('rows show a Not finished chip for an unfinished inspection',
      (tester) async {
    await _pump(tester, _FakeRepo([_ins('A1', 'Green')]), _FakePrefs());
    expect(find.text('Not finished'), findsOneWidget);
    expect(errors, isEmpty);
  });

  for (final c in {
    'phone': const Size(360, 740),
    'tablet': const Size(1024, 768),
  }.entries) {
    testWidgets('finish bar and sheet at 1.3x on ${c.key}', (tester) async {
      tester.view.physicalSize = c.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final also = unansweredItems(InspectionEntity.newDraft());
      final completion =
          InspectionCompletion.of(InspectionEntity.newDraft(), const []);
      String? jumped;
      await tester.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: FinishBar(
              completion: completion,
              onTap: () async =>
                  jumped = await showFinishSheet(ctx, completion, also),
            ),
          ),
        ),
      ));
      expect(find.text('Not finished: 6 things left'), findsOneWidget);
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(find.text('To finish this inspection'), findsOneWidget);
      final list = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(
          find.text('Also missing (does not block finishing)'), 200,
          scrollable: list.first);
      await tester.scrollUntilVisible(find.text('Battery'), -200,
          scrollable: list.first);
      await tester.tap(find.text('Battery'));
      await tester.pumpAndSettle();
      expect(jumped, 'materials');
      expect(errors, isEmpty);
    });
  }

  testWidgets('ready state shows Ready to finish', (tester) async {
    var e = InspectionEntity.newDraft();
    final completion = InspectionCompletion.fromCounts(
        answered: 10, total: 10, items: [
      for (final s in [
        MaterialSlot.airFilter,
        MaterialSlot.fuelFilter,
        MaterialSlot.lubeFilter,
        MaterialSlot.coolantFilter,
        MaterialSlot.battery,
      ])
        MaterialItem(id: s.wire, slot: s, partNumber: 'P')
    ]);
    expect(e.id, isNotEmpty);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FinishBar(completion: completion, onTap: () {}))));
    expect(find.text('Ready to finish'), findsOneWidget);
  });
}
