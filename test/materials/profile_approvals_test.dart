import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/profile_change.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/materials/infra/profile_changes_repository.dart';
import 'package:voltcore/modules/materials/presenter/materials_editor.dart';
import 'package:voltcore/modules/materials/presenter/materials_section_card.dart';
import 'package:voltcore/modules/materials/presenter/pages/profile_approvals_page.dart';

import 'fake_approval_gateway.dart';
import 'profile_change_test.dart' show MemBox, MemMaterials, item;

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

const _key = 'generac|rg|1';
const _owner = MaterialOwner.generator(
    key: _key, make: 'Generac', model: 'RG', serial: '1');

final _oil = item('o1', MaterialSlot.oilFilter,
    role: MaterialRole.primary, pn: 'LF3000', name: 'Oil filter');
final _air = item('a1', MaterialSlot.airFilter, pn: 'AF25');

/// Every test uses the in-memory box and a counter clock; Hive writes would
/// hang on the widget-test clock.
ProfileChangesRepository _changes(
  MemBox box, {
  String user = 'tech-1',
  FakeApprovalGateway? gateway,
}) {
  var n = 0;
  var t = DateTime.utc(2026, 11, 8, 9);
  return ProfileChangesRepository(
    box: box,
    upsert: (_, __, ___) async {},
    fetch: (_) async => const [],
    gateway: gateway ?? FakeApprovalGateway(),
    tenantId: () => 't',
    userId: () => user,
    newId: () => 'req-$user-${++n}',
    now: () => t = t.add(const Duration(minutes: 1)),
  );
}

Override _auth(UserRole role, {String id = 'tech-1', String name = 'Tess Tech'}) =>
    authStateProvider.overrideWith((ref) {
      final c = AuthController(ref, _FakeLogin(), _FakeLogout());
      c.state = AuthState(
        isAuthenticated: true,
        currentRole: role,
        userId: id,
        displayName: name,
      );
      return c;
    });

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({
  required List<Override> overrides,
  required Widget home,
  double textScale = 1.0,
}) =>
    ProviderScope(
      overrides: [
        stockLevelsProvider.overrideWith((ref) async => const <StockLevel>[]),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );

/// A page that opens the profile sheet.
class _Opener extends StatelessWidget {
  const _Opener();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showGeneratorPartsProfile(context,
                make: 'Generac', model: 'RG', serial: '1'),
            child: const Text('open profile'),
          ),
        ),
      );
}

/// Drops overflow reports (they are a layout check done separately) while
/// failing on anything else.
void _failOnOtherErrors() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
}

Future<ProfileChangeRequest> _seed(
  ProfileChangesRepository repo, {
  List<MaterialItem>? proposed,
  String note = 'Filter on site differs',
}) =>
    repo.propose(
      generatorKey: _key,
      make: 'Generac',
      model: 'RG',
      serial: '1',
      current: [_oil, _air],
      proposed: proposed ?? [_oil.copyWith(partNumber: 'LF3001'), _air],
      note: note,
      proposedByName: 'Tess Tech',
    );

void main() {
  const phone = Size(390, 844);
  const tablet = Size(1000, 1300);

  group('technician on the profile sheet', () {
    for (final (label, size) in [('phone', phone), ('tablet', tablet)]) {
      testWidgets('reads the profile, can propose, sees own waiting ($label, 1.3x)',
          (tester) async {
        _failOnOtherErrors();
        _size(tester, size);
        final box = MemBox();
        final repo = _changes(box);
        await _seed(repo);
        // Someone else's request is not shown to this technician.
        await _changes(box, user: 'tech-2').propose(
            generatorKey: _key,
            current: [_oil, _air],
            proposed: [_oil],
            note: 'other');
        final materials = MemMaterials({
          _owner.storeKey: [_oil, _air]
        });
        await tester.pumpWidget(_app(
          textScale: 1.3,
          overrides: [
            _auth(UserRole.tech),
            materialsRepositoryProvider.overrideWithValue(materials),
            profileChangesRepositoryProvider.overrideWithValue(repo),
          ],
          home: const _Opener(),
        ));
        await tester.tap(find.text('open profile'));
        await _settle(tester);

        expect(find.text('Propose a change'), findsOneWidget);
        expect(find.text('Waiting for approval'), findsOneWidget);
        expect(find.text('Withdraw'), findsOneWidget);
        expect(find.textContaining('waiting'), findsNothing);
        // Read-only: no way to add a part to the real profile.
        expect(find.text('Add another'), findsNothing);
        expect(find.textContaining('Add oil'), findsNothing);
      });
    }

    testWidgets('withdraw takes the request back', (tester) async {
      _failOnOtherErrors();
      _size(tester, phone);
      final box = MemBox();
      final repo = _changes(box);
      final r = await _seed(repo);
      await tester.pumpWidget(_app(
        overrides: [
          _auth(UserRole.tech),
          materialsRepositoryProvider
              .overrideWithValue(MemMaterials({_owner.storeKey: [_oil, _air]})),
          profileChangesRepositoryProvider.overrideWithValue(repo),
        ],
        home: const _Opener(),
      ));
      await tester.tap(find.text('open profile'));
      await _settle(tester);
      await tester.tap(find.text('Withdraw'));
      await _settle(tester);
      expect((await repo.byId(r.id))!.status, ProfileRequestStatus.withdrawn);
      expect(find.text('Withdraw'), findsNothing);
    });

    testWidgets(
        'proposing edits a copy, needs a reason, and leaves the profile alone',
        (tester) async {
      _failOnOtherErrors();
      _size(tester, phone);
      final box = MemBox();
      final repo = _changes(box);
      final materials = MemMaterials({
        _owner.storeKey: [_oil, _air]
      });
      await tester.pumpWidget(_app(
        textScale: 1.3,
        overrides: [
          _auth(UserRole.tech),
          materialsRepositoryProvider.overrideWithValue(materials),
          profileChangesRepositoryProvider.overrideWithValue(repo),
        ],
        home: const _Opener(),
      ));
      await tester.tap(find.text('open profile'));
      await _settle(tester);
      await tester.tap(find.text('Propose a change'));
      await _settle(tester);

      // Nothing edited yet: sending says to change something first.
      await tester.enterText(
          find.byKey(const ValueKey('proposal_reason')), 'Wrong part number');
      await tester.ensureVisible(find.byKey(const ValueKey('send_for_approval')));
      await tester.tap(find.byKey(const ValueKey('send_for_approval')));
      await _settle(tester);
      expect(find.text('Change something first, then send it.'), findsOneWidget);
      expect(await repo.all(), isEmpty);

      // Edit the copy.
      // The read-only profile sheet is still underneath; edit the copy on top.
      final pn = find.widgetWithText(TextFormField, 'LF3000').last;
      expect(find.widgetWithText(TextFormField, 'LF3000'), findsNWidgets(2));
      await tester.ensureVisible(pn);
      await tester.enterText(pn, 'LF3001');
      await tester.pump();

      // A blank reason is refused.
      await tester.enterText(find.byKey(const ValueKey('proposal_reason')), ' ');
      await tester.ensureVisible(find.byKey(const ValueKey('send_for_approval')));
      await tester.tap(find.byKey(const ValueKey('send_for_approval')));
      await _settle(tester);
      expect(find.text('Say briefly why this should change.'), findsOneWidget);
      expect(await repo.all(), isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('proposal_reason')), 'Wrong part number');
      await tester.tap(find.byKey(const ValueKey('send_for_approval')));
      await _settle(tester);

      final saved = await repo.all();
      expect(saved, hasLength(1));
      expect(saved.single.note, 'Wrong part number');
      expect(saved.single.proposedByName, 'Tess Tech');
      expect(saved.single.changes.single.kind, ProfileChangeKind.update);
      expect(saved.single.changes.single.fields.single.to, 'LF3001');
      // The real profile is untouched and nothing was written to it.
      expect(materials.store[_owner.storeKey]!.first.partNumber, 'LF3000');
      expect(materials.saves, 0);
      // Back on the profile sheet, the new request shows as waiting.
      expect(find.text('Waiting for approval'), findsOneWidget);
    });
  });

  group('editor on the profile sheet', () {
    for (final role in [UserRole.supervisor, UserRole.dispatcher, UserRole.admin]) {
      testWidgets('${role.name} sees a waiting chip and no Propose button',
          (tester) async {
        _failOnOtherErrors();
        _size(tester, phone);
        final box = MemBox();
        final repo = _changes(box);
        await _seed(repo);
        await _seed(repo, note: 'another');
        await tester.pumpWidget(_app(
          overrides: [
            _auth(role, id: 'boss-1', name: 'Boss'),
            materialsRepositoryProvider.overrideWithValue(
                MemMaterials({_owner.storeKey: [_oil, _air]})),
            profileChangesRepositoryProvider.overrideWithValue(repo),
          ],
          home: const _Opener(),
        ));
        await tester.tap(find.text('open profile'));
        await _settle(tester);

        expect(find.text('2 waiting'), findsOneWidget);
        expect(find.text('Propose a change'), findsNothing);
        expect(find.text('Withdraw'), findsNothing);
      });
    }

    testWidgets('no chip when nothing is waiting', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(_app(
        overrides: [
          _auth(UserRole.supervisor, id: 'boss-1'),
          materialsRepositoryProvider.overrideWithValue(MemMaterials()),
          profileChangesRepositoryProvider
              .overrideWithValue(_changes(MemBox())),
        ],
        home: const _Opener(),
      ));
      await tester.tap(find.text('open profile'));
      await _settle(tester);
      expect(find.textContaining('waiting'), findsNothing);
    });
  });

  group('approvals page', () {
    Future<
        ({
          ProfileChangesRepository repo,
          MemMaterials materials,
        })> open(
      WidgetTester tester, {
      required Size size,
      double scale = 1.0,
      List<MaterialItem>? profile,
      Future<void> Function(ProfileChangesRepository repo)? seed,
      FakeApprovalGateway? gateway,
    }) async {
      _size(tester, size);
      final box = MemBox();
      final repo = _changes(box, user: 'boss-1', gateway: gateway);
      final techRepo = _changes(box, user: 'tech-1');
      if (seed != null) {
        await seed(techRepo);
      } else {
        await _seed(techRepo, proposed: [
          _oil.copyWith(partNumber: 'LF3001'),
          item('f1', MaterialSlot.fuelFilter, pn: 'FS1000'),
        ]);
      }
      final materials = MemMaterials({
        _owner.storeKey: profile ?? [_oil, _air]
      });
      await tester.pumpWidget(_app(
        textScale: scale,
        overrides: [
          _auth(UserRole.supervisor, id: 'boss-1', name: 'Sam Supervisor'),
          materialsRepositoryProvider.overrideWithValue(materials),
          profileChangesRepositoryProvider.overrideWithValue(repo),
        ],
        home: const ProfileApprovalsPage(),
      ));
      await _settle(tester);
      return (repo: repo, materials: materials);
    }

    for (final (label, size) in [('phone', phone), ('tablet', tablet)]) {
      testWidgets('lists the request with who, why and the per-item diff ($label, 1.3x)',
          (tester) async {
        _failOnOtherErrors();
        await open(tester, size: size, scale: 1.3);
        expect(find.text('Generac RG  ·  SN 1'), findsOneWidget);
        expect(find.textContaining('Tess Tech'), findsOneWidget);
        expect(find.text('Reason: Filter on site differs'), findsOneWidget);
        // Changed part: old to new.
        expect(find.textContaining('LF3000 → LF3001'), findsOneWidget);
        // Added part and removed part.
        expect(find.text('Add'), findsOneWidget);
        expect(find.textContaining('FS1000'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);
        expect(find.byKey(const ValueKey('approve_all')), findsOneWidget);
        expect(find.byKey(const ValueKey('approve_selected')), findsOneWidget);
        expect(find.byKey(const ValueKey('reject')), findsOneWidget);
      });
    }

    testWidgets('empty state when nothing is waiting', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(_app(
        overrides: [
          _auth(UserRole.admin, id: 'boss-1'),
          materialsRepositoryProvider.overrideWithValue(MemMaterials()),
          profileChangesRepositoryProvider
              .overrideWithValue(_changes(MemBox())),
        ],
        home: const ProfileApprovalsPage(),
      ));
      await _settle(tester);
      expect(find.text('Nothing waiting'), findsOneWidget);
    });

    testWidgets('newest request is first', (tester) async {
      _failOnOtherErrors();
      await open(tester, size: tablet, seed: (repo) async {
        await _seed(repo, note: 'first one');
        await _seed(repo, note: 'second one');
      });
      final first = tester.getTopLeft(find.text('Reason: first one')).dy;
      final second = tester.getTopLeft(find.text('Reason: second one')).dy;
      expect(second, lessThan(first));
    });

    testWidgets('Approve applies every change to the profile and closes the request',
        (tester) async {
      _failOnOtherErrors();
      final ctx = await open(tester, size: tablet);
      await tester.tap(find.byKey(const ValueKey('approve_all')));
      await _settle(tester);

      final saved = ctx.materials.store[_owner.storeKey]!;
      final byId = {for (final i in saved) i.id: i};
      expect(byId['o1']!.partNumber, 'LF3001');
      expect(byId['f1']!.partNumber, 'FS1000');
      expect(byId.containsKey('a1'), isFalse);
      expect(ctx.materials.saves, 1);
      expect((await ctx.repo.all()).single.status, ProfileRequestStatus.approved);
      expect(find.text('Nothing waiting'), findsOneWidget);
    });

    testWidgets('Approve offline says Connect to approve and keeps it pending',
        (tester) async {
      _failOnOtherErrors();
      final gw = FakeApprovalGateway(offline: true);
      final ctx = await open(tester, size: tablet, gateway: gw);
      await tester.tap(find.byKey(const ValueKey('approve_all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Connect to approve'), findsOneWidget);
      expect((await ctx.repo.all()).single.status, ProfileRequestStatus.pending);
      expect(ctx.materials.saves, 0);
      expect(find.byKey(const ValueKey('approve_all')), findsOneWidget);
      // Back online, the same button works.
      gw.offline = false;
      await tester.tap(find.byKey(const ValueKey('approve_all')));
      await _settle(tester);
      expect((await ctx.repo.all()).single.status, ProfileRequestStatus.approved);
      expect(gw.approvals, hasLength(1));
    });

    testWidgets('Approve selected applies only the ticked changes',
        (tester) async {
      _failOnOtherErrors();
      final ctx = await open(tester, size: tablet);
      // Untick the add and the remove, leaving the part-number change.
      await tester.tap(find.byKey(const ValueKey('change_f1')));
      await tester.tap(find.byKey(const ValueKey('change_a1')));
      await tester.pump();
      expect(find.text('Approve selected (1)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('approve_selected')));
      await _settle(tester);

      final byId = {
        for (final i in ctx.materials.store[_owner.storeKey]!) i.id: i
      };
      expect(byId['o1']!.partNumber, 'LF3001');
      expect(byId.containsKey('f1'), isFalse);
      expect(byId.containsKey('a1'), isTrue);
    });

    testWidgets('Reject asks for an optional note and leaves the profile alone',
        (tester) async {
      _failOnOtherErrors();
      final ctx = await open(tester, size: phone, scale: 1.3);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reject')));
      await _settle(tester);
      await tester.enterText(
          find.byKey(const ValueKey('reject_note')), 'That is the old part');
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await _settle(tester);

      final r = (await ctx.repo.all()).single;
      expect(r.status, ProfileRequestStatus.rejected);
      expect(r.reviewNote, 'That is the old part');
      expect(ctx.materials.store[_owner.storeKey]!.first.partNumber, 'LF3000');
      expect(ctx.materials.saves, 0);
    });

    testWidgets('a change the profile has moved on from is flagged and not ticked',
        (tester) async {
      _failOnOtherErrors();
      final ctx = await open(
        tester,
        size: tablet,
        // Someone already changed the oil filter to something else.
        profile: [_oil.copyWith(partNumber: 'LF-OTHER'), _air],
        seed: (repo) => _seed(repo,
            proposed: [_oil.copyWith(partNumber: 'LF3001'), _air.copyWith(partNumber: 'AF26')]),
      );
      expect(find.text('Changed since proposed'), findsOneWidget);
      expect(find.text('Approve selected (1)'), findsOneWidget);

      // Approve applies what still applies.
      await tester.tap(find.byKey(const ValueKey('approve_all')));
      await _settle(tester);
      final byId = {
        for (final i in ctx.materials.store[_owner.storeKey]!) i.id: i
      };
      expect(byId['o1']!.partNumber, 'LF-OTHER');
      expect(byId['a1']!.partNumber, 'AF26');
    });
  });

  group('Propose to profile on a job form', () {
    const job = MaterialOwner.inspection(id: 'insp-1', equipmentKey: _key);

    Widget host(MemMaterials m, ProfileChangesRepository repo, bool canEdit,
            UserRole role) =>
        _app(
          textScale: 1.3,
          overrides: [
            _auth(role),
            materialsRepositoryProvider.overrideWithValue(m),
            profileChangesRepositoryProvider.overrideWithValue(repo),
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: MaterialsEditor(
                owner: job,
                mode: MaterialsMode.inspection,
                profileOwner: _owner,
                canEditProfile: canEdit,
              ),
            ),
          ),
        );

    testWidgets('a technician is offered Propose, not Save', (tester) async {
      _failOnOtherErrors();
      _size(tester, phone);
      await tester.pumpWidget(host(MemMaterials(), _changes(MemBox()), false,
          UserRole.tech));
      await _settle(tester);
      expect(find.text('Propose to profile'), findsOneWidget);
      expect(find.text('Save to profile'), findsNothing);
    });

    testWidgets('an editor is offered Save, not Propose', (tester) async {
      _failOnOtherErrors();
      _size(tester, phone);
      await tester.pumpWidget(host(MemMaterials(), _changes(MemBox()), true,
          UserRole.supervisor));
      await _settle(tester);
      expect(find.text('Save to profile'), findsOneWidget);
      expect(find.text('Propose to profile'), findsNothing);
    });

    testWidgets('proposing shows the diff against the profile and sends it',
        (tester) async {
      _failOnOtherErrors();
      _size(tester, phone);
      final box = MemBox();
      final repo = _changes(box);
      final materials = MemMaterials({
        _owner.storeKey: [_oil, _air],
        job.storeKey: [
          item('j1', MaterialSlot.airFilter, pn: 'AF99'),
          item('j2', MaterialSlot.oilFilter,
              role: MaterialRole.primary, pn: 'LF3000', name: 'Oil filter'),
        ],
      });
      await tester.pumpWidget(host(materials, repo, false, UserRole.tech));
      await _settle(tester);
      await tester.tap(find.text('Propose to profile'));
      await _settle(tester);

      expect(find.textContaining('AF25 → AF99'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('proposal_reason')), 'Site has AF99');
      await tester.ensureVisible(find.byKey(const ValueKey('send_for_approval')));
      await tester.tap(find.byKey(const ValueKey('send_for_approval')));
      await _settle(tester);

      final r = (await repo.all()).single;
      expect(r.generatorKey, _key);
      expect(r.note, 'Site has AF99');
      expect(r.changes.single.itemId, 'a1');
      expect(r.changes.single.fields.single.to, 'AF99');
      expect(materials.store[_owner.storeKey]!.length, 2);
      expect(materials.saves, 0);
    });
  });
}
