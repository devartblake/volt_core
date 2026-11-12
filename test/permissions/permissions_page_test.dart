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
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/permissions/domain/permission.dart';
import 'package:voltcore/modules/permissions/infra/permission_overrides_repository.dart';
import 'package:voltcore/modules/permissions/presenter/permission_providers.dart';
import 'package:voltcore/modules/permissions/presenter/permissions_page.dart';

import 'permission_test.dart' show FakeCache, FakeOverridesRepo;

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class _Admin extends Fake implements AdminRepository {
  _Admin(this.members);
  final List<TenantMemberEntity> members;

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async => members;

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() =>
      throw UnimplementedError();
}

class _Divisions implements DivisionRepository {
  _Divisions(this.items);
  final List<Division> items;

  @override
  Future<List<Division>> list() async => items;

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

TenantMemberEntity _member(String id, String name, UserRole role,
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

const _gen = Division(id: 'd1', name: 'Generators', sortOrder: 0);
const _fire = Division(id: 'd2', name: 'Fire alarm', sortOrder: 1);

Future<void> _pump(
  WidgetTester t, {
  required FakeOverridesRepo repo,
  String userId = 'u1',
  Size size = const Size(360, 800),
  double scale = 1.3,
  Brightness brightness = Brightness.light,
  List<TenantMemberEntity>? members,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      _auth(),
      adminRepositoryProvider.overrideWithValue(_Admin(members ??
          [
            _member('u1', 'Ann Apprentice', UserRole.apprentice,
                divisions: ['d1', 'd2']),
            _member('u2', 'Tom Technician', UserRole.tech),
          ])),
      divisionRepositoryProvider
          .overrideWithValue(_Divisions(const [_gen, _fire])),
      permissionOverridesRepositoryProvider.overrideWithValue(repo),
      permissionOverridesCacheProvider.overrideWithValue(FakeCache()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: PermissionsPage(userId: userId),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    for (final b in Brightness.values) {
      testWidgets(
          'renders every permission with no overflow at 1.3x on ${size.width.toInt()}px ${b.name}',
          (t) async {
        await _pump(t, repo: FakeOverridesRepo(), size: size, brightness: b);
        expect(find.byKey(const Key('permissions_banner')), findsOneWidget);
        expect(find.text(kPermissionsBannerText), findsOneWidget);
        // Walk the whole (lazy) list so every row is laid out once.
        final scrollable = find.byType(Scrollable).first;
        for (final p in Permission.values) {
          await t.scrollUntilVisible(find.byKey(Key('perm_row_${p.key}')), 300,
              scrollable: scrollable);
          expect(find.byKey(Key('perm_row_${p.key}')), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('shows the member, role, divisions, role default and result',
      (t) async {
    await _pump(t, repo: FakeOverridesRepo());
    expect(find.text('Ann Apprentice'), findsOneWidget);
    expect(find.text('Apprentice'), findsWidgets);
    expect(find.byKey(const Key('permissions_division_0')), findsOneWidget);
    expect(find.byKey(const Key('permissions_division_1')), findsOneWidget);
    expect(_text(t, 'perm_default_sign_off_work'),
        'Apprentice role default: No');
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: No');
  });

  testWidgets('Allow then Deny then Role default saves and shows the result',
      (t) async {
    final repo = FakeOverridesRepo();
    await _pump(t, repo: repo);

    await _tap(t, 'perm_choice_sign_off_work_allow');
    expect(repo.writes, ['u1:sign_off_work:allow']);
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: Yes (overridden)');

    await _tap(t, 'perm_choice_sign_off_work_deny');
    expect(repo.writes.last, 'u1:sign_off_work:deny');
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: No (overridden)');

    await _tap(t, 'perm_choice_sign_off_work_roleDefault');
    expect(repo.writes.last, 'u1:sign_off_work:reset');
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: No');
    expect(repo.byUser['u1'], isEmpty);
  });

  testWidgets('existing overrides are loaded and shown selected', (t) async {
    final repo = FakeOverridesRepo(byUser: {
      'u1': {Permission.manageInventory: PermissionEffect.allow},
    });
    await _pump(t, repo: repo);
    await t.scrollUntilVisible(
        find.byKey(const Key('perm_row_manage_inventory')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(_text(t, 'perm_effective_manage_inventory'),
        'Result: Yes (overridden)');
    final chip = t.widget<ChoiceChip>(
        find.byKey(const Key('perm_choice_manage_inventory_allow')));
    expect(chip.selected, isTrue);
  });

  testWidgets('Reset all removes every override after confirming', (t) async {
    final repo = FakeOverridesRepo(byUser: {
      'u1': {
        Permission.signOffWork: PermissionEffect.allow,
        Permission.manageFleet: PermissionEffect.deny,
      },
    });
    await _pump(t, repo: repo);
    final reset = find.byKey(const Key('permissions_reset_all'));
    expect(t.widget<OutlinedButton>(reset).onPressed, isNotNull);
    await t.tap(reset);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('permissions_reset_confirm')));
    await t.pumpAndSettle();
    expect(repo.writes, ['u1:reset_all']);
    expect(repo.byUser['u1'], isEmpty);
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: No');
    // Nothing left to reset.
    expect(t.widget<OutlinedButton>(reset).onPressed, isNull);
  });

  testWidgets('cancelling Reset all keeps the overrides', (t) async {
    final repo = FakeOverridesRepo(byUser: {
      'u1': {Permission.signOffWork: PermissionEffect.allow},
    });
    await _pump(t, repo: repo);
    await t.tap(find.byKey(const Key('permissions_reset_all')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(repo.writes, isEmpty);
  });

  testWidgets('offline on load: says so and Retry works', (t) async {
    final repo = FakeOverridesRepo()..offline = true;
    await _pump(t, repo: repo);
    expect(find.text('Connect to the internet to change permissions.'),
        findsOneWidget);
    expect(find.byKey(const Key('perm_row_sign_off_work')), findsNothing);
    repo.offline = false;
    await t.tap(find.byKey(const Key('permissions_retry')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('perm_row_sign_off_work')), findsOneWidget);
  });

  testWidgets('going offline before a change shows the message and keeps the old value',
      (t) async {
    final repo = FakeOverridesRepo();
    await _pump(t, repo: repo);
    repo.offline = true;
    await _tap(t, 'perm_choice_sign_off_work_allow');
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Connect to the internet to change permissions.'),
        findsOneWidget);
    expect(_text(t, 'perm_effective_sign_off_work'), 'Result: No');
    expect(repo.writes, isEmpty);
  });

  testWidgets('an unknown member shows a not-found state', (t) async {
    await _pump(t, repo: FakeOverridesRepo(), userId: 'nobody');
    expect(find.text('Member not found'), findsOneWidget);
  });

  testWidgets('editing yourself refreshes your own effective permissions',
      (t) async {
    final repo = FakeOverridesRepo(mine: const {});
    await _pump(t,
        repo: repo,
        userId: 'admin1',
        members: [_member('admin1', 'Boss', UserRole.admin)]);
    repo.mine = {Permission.manageInventory: PermissionEffect.deny};
    await _tap(t, 'perm_choice_manage_inventory_deny');
    final container = ProviderScope.containerOf(
        t.element(find.byType(PermissionsPage)));
    expect(container.read(permissionOverridesProvider),
        {Permission.manageInventory: PermissionEffect.deny});
  });
}
