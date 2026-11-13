import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/settings/presenter/widgets/daily_digest_tile.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthController {
  _FakeAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements DigestPreferenceRepository {
  _FakeRepo({this.optOut = false, this.failWith});

  bool? optOut;
  Object? failWith;
  final writes = <bool>[];

  @override
  Future<bool?> readOptOut() async => optOut;

  @override
  Future<void> writeOptOut(bool value) async {
    if (failWith != null) throw failWith!;
    writes.add(value);
    optOut = value;
  }
}

AuthState _auth(UserRole role) => AuthState(
      isAuthenticated: true,
      currentRole: role,
      userId: 'u1',
      email: 'a@example.com',
      displayName: 'A',
      grantedRoles: {role},
    );

Widget _app(_FakeRepo repo, UserRole role,
        {ThemeMode mode = ThemeMode.light, double scale = 1}) =>
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuth(_auth(role))),
        digestPreferenceRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        themeMode: mode,
        theme: ThemeData(),
        darkTheme: ThemeData(brightness: Brightness.dark),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: c!,
        ),
        home: const Scaffold(body: SingleChildScrollView(child: DailyDigestTile())),
      ),
    );

Switch _switch(WidgetTester t) =>
    t.widget<Switch>(find.descendant(
        of: find.byKey(const Key('daily_digest_switch')),
        matching: find.byType(Switch)));

void main() {
  group('role visibility', () {
    for (final role in UserRole.values) {
      testWidgets(role.name, (tester) async {
        await tester.pumpWidget(_app(_FakeRepo(), role));
        await tester.pump();
        final shown = role == UserRole.admin ||
            role == UserRole.supervisor ||
            role == UserRole.dispatcher;
        expect(find.byKey(const Key('daily_digest_switch')),
            shown ? findsOneWidget : findsNothing);
      });
    }
  });

  testWidgets('on means receive; toggling writes opt-out', (tester) async {
    final repo = _FakeRepo(optOut: false);
    await tester.pumpWidget(_app(repo, UserRole.admin));
    await tester.pump();
    await tester.pump();
    expect(find.text('Email me the daily summary'), findsOneWidget);
    expect(_switch(tester).value, isTrue);

    await tester.tap(find.byKey(const Key('daily_digest_switch')));
    await tester.pump();
    await tester.pump();
    expect(repo.writes, [true]);
    expect(_switch(tester).value, isFalse);

    await tester.tap(find.byKey(const Key('daily_digest_switch')));
    await tester.pump();
    await tester.pump();
    expect(repo.writes, [true, false]);
    expect(_switch(tester).value, isTrue);
  });

  testWidgets('opted-out user sees the switch off', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo(optOut: true), UserRole.dispatcher));
    await tester.pump();
    await tester.pump();
    expect(_switch(tester).value, isFalse);
  });

  testWidgets('offline: message shown and the switch does not flip',
      (tester) async {
    final repo = _FakeRepo(optOut: false, failWith: const DigestOfflineException());
    await tester.pumpWidget(_app(repo, UserRole.supervisor));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily_digest_switch')));
    await tester.pump();
    await tester.pump();
    expect(find.text(kDigestOfflineMessage), findsOneWidget);
    expect(_switch(tester).value, isTrue);
    expect(repo.writes, isEmpty);
  });

  testWidgets('missing column (migration not run): plain message',
      (tester) async {
    final repo = _FakeRepo(
        optOut: null, failWith: const DigestColumnMissingException());
    await tester.pumpWidget(_app(repo, UserRole.admin));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily_digest_switch')));
    await tester.pump();
    await tester.pump();
    expect(find.text(kDigestUnavailableMessage), findsOneWidget);
    expect(_switch(tester).value, isTrue);
  });

  testWidgets('other failure: generic message', (tester) async {
    final repo = _FakeRepo(failWith: StateError('boom'));
    await tester.pumpWidget(_app(repo, UserRole.admin));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily_digest_switch')));
    await tester.pump();
    await tester.pump();
    expect(find.text(kDigestSaveFailedMessage), findsOneWidget);
  });

  const sizes = {'phone': Size(360, 800), 'tablet': Size(1280, 800)};
  for (final size in sizes.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('no overflow at 1.3x: ${size.key} ${mode.name}',
          (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
            _app(_FakeRepo(), UserRole.admin, mode: mode, scale: 1.3));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('daily_digest_switch')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
