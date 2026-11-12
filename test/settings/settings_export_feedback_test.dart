import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/nav_profile.dart';
import 'package:voltcore/app/nav_style_provider.dart';
import 'package:voltcore/core/services/settings/app_preferences_provider.dart';
import 'package:voltcore/core/services/storage/user_data_export_service.dart';
import 'package:voltcore/core/services/storage/user_data_exporter_provider.dart';
import 'package:voltcore/core/theme/theme_mode_provider.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
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


Future<void> _pumpWith(WidgetTester tester, UserDataExporter exporter) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1280);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ..._overrides(_signedIn),
      userDataExporterProvider.overrideWithValue(exporter),
    ],
    child: const MaterialApp(home: SettingsPage()),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.scrollUntilVisible(find.text('Export Data'), 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('export failure: plain error snackbar, no raw exception',
      (tester) async {
    await _pumpWith(tester, () async => throw StateError('disk exploded'));
    await tester.tap(find.text('Export Data'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not export your data. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('disk exploded'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export success shows where it was saved', (tester) async {
    await _pumpWith(
        tester,
        () async => const UserDataExportResult(
            saved: true, destination: '/downloads/x.json'));
    await tester.tap(find.text('Export Data'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Inspection data exported to /downloads/x.json'),
        findsOneWidget);
  });

  testWidgets('export cancelled shows no snackbar', (tester) async {
    await _pumpWith(
        tester, () async => const UserDataExportResult(saved: false));
    await tester.tap(find.text('Export Data'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
