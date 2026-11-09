import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/division.dart';
import 'package:voltcore/modules/admin/domain/entities/admin_dashboard_stats_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/infra/division_repository.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository_impl.dart';
import 'package:voltcore/modules/admin/presenter/pages/technicians_page.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class _Repo extends Fake implements AdminRepository {
  _Repo(this.members);
  List<TenantMemberEntity> members;
  final divisionWrites = <String>[];
  final roleWrites = <String>[];

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async => members;

  @override
  Future<void> setMemberDivisions({
    required TenantMemberEntity member,
    required List<String> divisionIds,
  }) async {
    divisionWrites.add('${member.userId}:${divisionIds.join('+')}');
  }

  @override
  Future<void> assignTenantRole({
    required TenantMemberEntity member,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    roleWrites.add('${member.userId}:${newRole.wire}');
  }

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() =>
      throw UnimplementedError();
}

class _Divisions implements DivisionRepository {
  _Divisions(this.items, {this.fail = false});
  final List<Division> items;
  final bool fail;
  @override
  Future<List<Division>> list() async {
    if (fail) throw const DivisionsOfflineException();
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

Override _auth() => authStateProvider.overrideWith((ref) {
      final c = AuthController(ref, _FakeLogin(), _FakeLogout());
      c.state = const AuthState(
        isAuthenticated: true,
        currentRole: UserRole.admin,
        userId: 'admin1',
        displayName: 'Boss',
        grantedRoles: {UserRole.admin},
      );
      return c;
    });

const _gen = Division(id: 'd1', name: 'Generators', sortOrder: 0);
const _fire = Division(id: 'd2', name: 'Fire alarm', sortOrder: 1);

TenantMemberEntity _m(String id, String name, UserRole role,
        {List<String> divisions = const []}) =>
    TenantMemberEntity(
      tenantId: 't1',
      userId: id,
      displayName: name,
      email: '$id@example.com',
      role: role,
      isActive: true,
      divisionIds: divisions,
    );

Future<_Repo> _pump(
  WidgetTester t, {
  required List<TenantMemberEntity> members,
  List<Division> divisions = const [_gen, _fire],
  bool divisionsFail = false,
  Size size = const Size(360, 800),
  double scale = 1.3,
}) async {
  // Tall, so every member card is built (the list is lazy); the width is what
  // matters for overflow.
  t.view.physicalSize = Size(size.width, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = _Repo(members);
  await t.pumpWidget(ProviderScope(
    overrides: [
      _auth(),
      adminRepositoryProvider.overrideWithValue(repo),
      divisionRepositoryProvider
          .overrideWithValue(_Divisions(divisions, fail: divisionsFail)),
    ],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const TechniciansPage(),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  return repo;
}

final _members = [
  _m('u1', 'Ann Apprentice', UserRole.apprentice, divisions: ['d1']),
  _m('u2', 'Tom Technician', UserRole.tech),
  _m('u3', 'Dana Dispatcher With A Rather Long Name', UserRole.dispatcher,
      divisions: ['d1', 'd2']),
];

void main() {
  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    testWidgets(
        'shows role and division chips with no overflow at 1.3x on ${size.width.toInt()}px',
        (t) async {
      await _pump(t, members: _members, size: size);
      expect(t.takeException(), isNull);

      expect(find.descendant(
              of: find.byKey(const Key('role_chip_u1')),
              matching: find.text('Apprentice')),
          findsOneWidget);
      expect(find.descendant(
              of: find.byKey(const Key('division_chip_u1_0')),
              matching: find.text('Generators')),
          findsOneWidget);
      // Several divisions: one chip each.
      expect(find.byKey(const Key('division_chip_u3_0')), findsOneWidget);
      expect(find.byKey(const Key('division_chip_u3_1')), findsOneWidget);
      // No division: no chip.
      expect(find.byKey(const Key('division_chip_u2_0')), findsNothing);
      expect(find.descendant(
              of: find.byKey(const Key('role_chip_u2')),
              matching: find.text('Technician')),
          findsOneWidget);
    });
  }

  testWidgets('the role control offers Apprentice', (t) async {
    await _pump(t, members: _members);
    await t.tap(find.byKey(const Key('role_dropdown_u2')));
    await t.pumpAndSettle();
    expect(find.text('Apprentice'), findsWidgets);
    expect(find.text('Technician'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('changing a role to Apprentice asks, then writes the wire value',
      (t) async {
    final repo = await _pump(t, members: _members);
    await t.tap(find.byKey(const Key('role_dropdown_u2')));
    await t.pumpAndSettle();
    await t.tap(find.text('Apprentice').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Technician → Apprentice'), findsOneWidget);
    await t.tap(find.text('Change Role'));
    await t.pumpAndSettle();
    expect(repo.roleWrites, ['u2:apprentice']);
    expect(repo.divisionWrites, isEmpty);
  });

  testWidgets('cancelling the role change leaves the shown role alone',
      (t) async {
    final repo = await _pump(t, members: _members);
    await t.tap(find.byKey(const Key('role_dropdown_u2')));
    await t.pumpAndSettle();
    await t.tap(find.text('Apprentice').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(repo.roleWrites, isEmpty);
    final dropdown = t.widget<DropdownButton<UserRole>>(
        find.byKey(const Key('role_dropdown_u2')));
    expect(dropdown.value, UserRole.tech);
  });

  Future<void> openPicker(WidgetTester t, String userId) async {
    await t.ensureVisible(find.byKey(Key('division_picker_$userId')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('division_picker_$userId')));
    await t.pumpAndSettle();
  }

  testWidgets('choosing several divisions writes the set, no role row',
      (t) async {
    final repo = await _pump(t, members: _members);
    await openPicker(t, 'u2');
    await t.tap(find.byKey(const Key('division_option_d2')));
    await t.tap(find.byKey(const Key('division_option_d1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('division_picker_done')));
    await t.pumpAndSettle();
    // Admin-arranged order: Generators (d1) before Fire alarm (d2).
    expect(repo.divisionWrites, ['u2:d1+d2']);
    expect(repo.roleWrites, isEmpty);
    expect(find.byKey(const Key('division_chip_u2_0')), findsOneWidget);
    expect(find.byKey(const Key('division_chip_u2_1')), findsOneWidget);
  });

  testWidgets('cancelling the picker writes nothing', (t) async {
    final repo = await _pump(t, members: _members);
    await openPicker(t, 'u2');
    await t.tap(find.byKey(const Key('division_option_d2')));
    await t.tap(find.byKey(const Key('division_picker_cancel')));
    await t.pumpAndSettle();
    expect(repo.divisionWrites, isEmpty);
  });

  testWidgets('removing one division keeps the others', (t) async {
    final repo = await _pump(t, members: _members);
    await openPicker(t, 'u3');
    await t.tap(find.byKey(const Key('division_option_d1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('division_picker_done')));
    await t.pumpAndSettle();
    expect(repo.divisionWrites, ['u3:d2']);
    expect(find.byKey(const Key('division_chip_u3_1')), findsNothing);
  });

  testWidgets('clearing every division writes an empty set', (t) async {
    final repo = await _pump(t, members: _members);
    await openPicker(t, 'u1');
    await t.tap(find.byKey(const Key('division_option_d1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('division_picker_done')));
    await t.pumpAndSettle();
    expect(repo.divisionWrites, ['u1:']);
    expect(find.byKey(const Key('division_chip_u1_0')), findsNothing);
  });

  testWidgets('a very long division name wraps/ellipsises without overflow',
      (t) async {
    await _pump(t, members: [
      _m('u1', 'Ann Apprentice', UserRole.apprentice,
          divisions: ['d1', 'd2', 'd3']),
    ], divisions: const [
      _gen,
      _fire,
      Division(
          id: 'd3',
          name: 'An extremely long division name that goes on and on and on',
          sortOrder: 2),
    ]);
    expect(find.byKey(const Key('division_chip_u1_2')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('search finds people by division name', (t) async {
    await _pump(t, members: _members);
    await t.enterText(find.byType(TextField).first, 'fire alarm');
    await t.pump();
    expect(find.text('Ann Apprentice'), findsNothing);
    expect(find.textContaining('Dana Dispatcher'), findsOneWidget);
  });

  testWidgets('without divisions the page still lists people, no division UI',
      (t) async {
    await _pump(t,
        members: [_m('u2', 'Tom Technician', UserRole.tech)],
        divisionsFail: true);
    expect(find.text('Tom Technician'), findsOneWidget);
    expect(find.byKey(const Key('division_picker_u2')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('an inactive division stays visible on its members', (t) async {
    await _pump(t, members: [
      _m('u1', 'Ann Apprentice', UserRole.apprentice, divisions: ['d9']),
    ], divisions: const [
      _gen,
      Division(id: 'd9', name: 'Legacy', isActive: false),
    ]);
    expect(find.byKey(const Key('division_chip_u1_0')), findsOneWidget);
    await openPicker(t, 'u1');
    expect(find.text('Legacy (not offered)'), findsWidgets);
  });
}
