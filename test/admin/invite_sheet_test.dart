import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/division.dart';
import 'package:voltcore/modules/admin/domain/entities/admin_dashboard_stats_entity.dart';
import 'package:voltcore/modules/admin/infra/division_repository.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository_impl.dart';
import 'package:voltcore/modules/admin/infra/services/invite_service.dart';
import 'package:voltcore/modules/admin/presenter/pages/technicians_page.dart';
import 'package:voltcore/modules/admin/presenter/widgets/invite_member_sheet.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class _FakeRepo extends Fake implements AdminRepository {
  int loads = 0;

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async {
    loads++;
    return const [];
  }

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() =>
      throw UnimplementedError();
}

class _FakeInvite implements InviteService {
  _FakeInvite({this.failure});
  final InviteFailure? failure;
  final requests = <InviteRequest>[];

  @override
  Future<InviteResult> invite(InviteRequest request) async {
    requests.add(request);
    if (failure != null) throw failure!;
    return InviteResult(userId: 'u2', invited: true, role: request.role);
  }
}

Override _auth(UserRole role) => authStateProvider.overrideWith((ref) {
      final c = AuthController(ref, _FakeLogin(), _FakeLogout());
      c.state = AuthState(
        isAuthenticated: true,
        currentRole: role,
        userId: 'u1',
        displayName: 'Test',
        grantedRoles: {role},
      );
      return c;
    });

Future<_FakeRepo> _pump(
  WidgetTester tester, {
  UserRole role = UserRole.admin,
  required _FakeInvite invite,
  bool online = true,
  Size size = const Size(360, 800),
  double textScale = 1.3,
  List<Division> divisions = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _auth(role),
        adminRepositoryProvider.overrideWithValue(repo),
        inviteServiceProvider.overrideWithValue(invite),
        divisionsProvider.overrideWith((ref) async => divisions),
        inviteOnlineCheckProvider.overrideWithValue(() async => online),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TechniciansPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Invite'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _fillAndSend(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), ' Ann ');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'), ' Ann@Example.com ');
  await tester.ensureVisible(find.text('Send invitation'));
  await tester.tap(find.text('Send invitation'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late List<String> overflows;
  void Function(FlutterErrorDetails)? oldHandler;

  setUp(() {
    overflows = [];
    oldHandler = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        overflows.add(d.exceptionAsString());
      } else {
        oldHandler?.call(d);
      }
    };
  });
  tearDown(() => FlutterError.onError = oldHandler);

  testWidgets('non-admin does not see Invite', (tester) async {
    await _pump(tester, role: UserRole.supervisor, invite: _FakeInvite());
    expect(find.text('Invite'), findsNothing);
  });

  testWidgets('admin sees Invite', (tester) async {
    await _pump(tester, invite: _FakeInvite());
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('no divisions defined: no Division field, request has none',
      (tester) async {
    final invite = _FakeInvite();
    await _pump(tester, invite: invite);
    await _openSheet(tester);
    expect(find.byKey(const Key('invite_division')), findsNothing);
    await _fillAndSend(tester);
    expect(invite.requests.single.divisionId, isNull);
    expect(invite.requests.single.toBody().containsKey('divisionId'), isFalse);
  });

  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    testWidgets(
        'Apprentice and a division can be chosen, no overflow at 1.3x on ${size.width.toInt()}px',
        (tester) async {
      final invite = _FakeInvite();
      await _pump(tester,
          invite: invite,
          size: size,
          divisions: const [
            Division(id: 'd1', name: 'Generators'),
            Division(id: 'd2', name: 'Legacy', isActive: false),
          ]);
      await _openSheet(tester);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<UserRole>));
      await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apprentice').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot sign off or delete work'),
          findsOneWidget);

      final field = find.byKey(const Key('invite_division'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      // Inactive divisions are not offered.
      expect(find.text('Legacy'), findsNothing);
      await tester.tap(find.text('Generators').last);
      await tester.pumpAndSettle();

      await _fillAndSend(tester);
      expect(invite.requests.single.role, UserRole.apprentice);
      expect(invite.requests.single.divisionId, 'd1');
      expect(invite.requests.single.toBody()['role'], 'apprentice');
      expect(invite.requests.single.toBody()['divisionId'], 'd1');
      expect(overflows, isEmpty);
    });
  }

  testWidgets('offline explains and does not open the sheet', (tester) async {
    await _pump(tester, invite: _FakeInvite(), online: false);
    await _openSheet(tester);
    expect(find.text('Connect to the internet to invite someone.'),
        findsOneWidget);
    expect(find.text('Send invitation'), findsNothing);
  });

  testWidgets('sheet validates before calling the service', (tester) async {
    final invite = _FakeInvite();
    await _pump(tester, invite: invite);
    await _openSheet(tester);

    await tester.ensureVisible(find.text('Send invitation'));
    await tester.tap(find.text('Send invitation'));
    await tester.pump();
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(invite.requests, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Ann');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone (optional)'), 'abc');
    await tester.ensureVisible(find.text('Send invitation'));
    await tester.tap(find.text('Send invitation'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use digits, spaces and + - ( ) only.'), findsOneWidget);
    expect(invite.requests, isEmpty);
  });

  testWidgets('valid submit calls the fake, shows success, refreshes',
      (tester) async {
    final invite = _FakeInvite();
    final repo = await _pump(tester, invite: invite);
    final before = repo.loads;
    await _openSheet(tester);
    await _fillAndSend(tester);

    expect(invite.requests, hasLength(1));
    expect(invite.requests.single.email, 'ann@example.com');
    expect(invite.requests.single.displayName, 'Ann');
    expect(invite.requests.single.role, UserRole.tech);
    expect(find.text('Send invitation'), findsNothing);
    expect(find.text('Invitation sent to ann@example.com'), findsOneWidget);
    expect(repo.loads, greaterThan(before));
  });

  for (final entry in {
    InviteFailureKind.notAllowed:
        'You are not allowed to invite people. Ask an admin.',
    InviteFailureKind.tooMany:
        'Too many invitations just now. Try again in a while.',
    InviteFailureKind.offline: 'Connect to the internet to invite someone.',
    InviteFailureKind.server:
        'The invitation could not be sent. Try again later.',
  }.entries) {
    testWidgets('failure ${entry.key.name} stays in the sheet in plain words',
        (tester) async {
      final invite =
          _FakeInvite(failure: InviteFailure(entry.key, entry.value));
      await _pump(tester, invite: invite);
      await _openSheet(tester);
      await _fillAndSend(tester);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Send invitation'), findsOneWidget);
    });
  }

  testWidgets('role help follows the selected role', (tester) async {
    await _pump(tester, invite: _FakeInvite());
    await _openSheet(tester);
    expect(find.textContaining('Does the field work'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Dispatcher').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Plans the schedule'), findsOneWidget);
  });

  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    testWidgets('1.3x text at ${size.width.toInt()}x800: no overflow',
        (tester) async {
      await _pump(tester, invite: _FakeInvite(), size: size);
      await _openSheet(tester);
      await tester.ensureVisible(find.text('Send invitation'));
      await tester.tap(find.text('Send invitation'));
      await tester.pump();
      expect(find.text('Send invitation'), findsOneWidget);
      expect(overflows, isEmpty);
    });
  }
}
