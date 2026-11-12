import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/nav_profile.dart';
import 'package:voltcore/app/nav_style_provider.dart';
import 'package:voltcore/core/services/settings/app_preferences_provider.dart';
import 'package:voltcore/core/theme/theme_mode_provider.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/presenter/pages/login_page.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/inspections/presenter/controllers/user_profile_controller.dart';
import 'package:voltcore/modules/settings/presenter/pages/settings_page.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthController {
  _FakeAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePrefs extends StateNotifier<AppPreferences>
    implements AppPreferencesController {
  _FakePrefs()
      : super(const AppPreferences(
          notificationsEnabled: true,
          autoSyncEnabled: true,
          language: 'English',
          dateFormat: 'MM/DD/YYYY',
        ));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTheme extends StateNotifier<ThemeMode>
    implements ThemeModeController {
  _FakeTheme() : super(ThemeMode.light);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNav extends StateNotifier<NavStyle> implements NavStyleController {
  _FakeNav() : super(NavStyle.rail);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _signedIn = AuthState(
  isAuthenticated: true,
  currentRole: UserRole.admin,
  userId: 'u1',
  email: 'admin@example.com',
  displayName: 'Admin User',
  grantedRoles: {UserRole.admin},
);

List<Override> _overrides(AuthState auth) => [
      authStateProvider.overrideWith((ref) => _FakeAuth(auth)),
      appPreferencesProvider.overrideWith((ref) => _FakePrefs()),
      themeModeProvider.overrideWith((ref) => _FakeTheme()),
      navStyleProvider.overrideWith((ref) => _FakeNav()),
      userProfileProvider.overrideWith((ref) => auth.isAuthenticated
          ? const AppUserProfile(
              displayName: 'Admin User',
              email: 'admin@example.com',
              avatarUrl: null,
              currentTenant: 'Acme Corp',
              tenants: ['Acme Corp'],
            )
          : null),
    ];

const _sizes = <String, Size>{
  'phone': Size(360, 800),
  'tablet portrait': Size(800, 1280),
  'tablet landscape': Size(1280, 800),
};

Future<List<String>> _pump(
  WidgetTester tester,
  Widget page,
  Size size,
  AuthState auth,
) async {
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      overflows.add(text);
    } else {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(auth),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  return overflows;
}

void main() {
  group('1.3x text scale', () {
    for (final entry in _sizes.entries) {
      testWidgets('settings page: ${entry.key}', (tester) async {
        final overflows = await _pump(
            tester, const SettingsPage(), entry.value, _signedIn);
        expect(overflows, isEmpty);
        // Scroll to the bottom to lay out every row.
        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 200));
        expect(overflows, isEmpty);
      });

      testWidgets('login page: ${entry.key}', (tester) async {
        final overflows = await _pump(
            tester, const LoginPage(), entry.value,
            const AuthState.unauthenticated());
        expect(overflows, isEmpty);
      });
    }
  });

  testWidgets('settings groups appear in order', (tester) async {
    await _pump(tester, const SettingsPage(), const Size(800, 3000), _signedIn);
    double top(String t) => tester.getTopLeft(find.text(t).first).dy;
    expect(top('Account') < top('Appearance'), isTrue);
    expect(top('Appearance') < top('Data & Sync'), isTrue);
    expect(top('Data & Sync') < top('PDF'), isTrue);
    expect(top('PDF') < top('About'), isTrue);
    expect(find.text('Sync centre'), findsOneWidget);
    expect(find.text('Inspection PDF template'), findsOneWidget);
    expect(find.text('Inspection summary page'), findsWidgets);
  });
}
