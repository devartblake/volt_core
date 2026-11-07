import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/presenter/pages/login_page.dart';
import 'package:voltcore/modules/auth/presenter/widgets/login/login_validators.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthController {
  _FakeAuth(this.onLogin) : super(const AuthState.unauthenticated());

  final Future<void> Function(String email, String password) onLogin;

  @override
  Future<void> login({
    required UserRole role,
    required String email,
    required String password,
  }) =>
      onLogin(email, password);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Future<void> Function(String, String) onLogin,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => _FakeAuth(onLogin))],
      child: const MaterialApp(home: LoginPage()),
    ),
  );
}

Finder get _signIn => find.widgetWithText(ElevatedButton, 'Sign in');

bool _enabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed != null;

void main() {
  group('LoginValidators', () {
    test('email', () {
      expect(LoginValidators.email(''), isNotNull);
      expect(LoginValidators.email('  '), isNotNull);
      expect(LoginValidators.email('abc'), isNotNull);
      expect(LoginValidators.email('a@b'), isNotNull);
      expect(LoginValidators.email('a b@c.com'), isNotNull);
      expect(LoginValidators.email('a@b.com'), isNull);
      expect(LoginValidators.email(' tech@as-electric.co.uk '), isNull);
    });

    test('password', () {
      expect(LoginValidators.password(''), isNotNull);
      expect(LoginValidators.password(null), isNotNull);
      expect(LoginValidators.password('x'), isNull);
    });

    test('describeError strips prefixes', () {
      expect(LoginValidators.describeError(Exception('Invalid login')),
          'Invalid login');
    });
  });

  group('LoginPage', () {
    testWidgets('button disabled until email and password are valid',
        (tester) async {
      await _pump(tester, (_, __) async {});
      expect(_enabled(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.pump();
      expect(_enabled(tester), isFalse);
      expect(find.textContaining('valid email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.pump();
      expect(_enabled(tester), isTrue);
      expect(find.textContaining('valid email'), findsNothing);
    });

    testWidgets('empty password shows inline error after interaction',
        (tester) async {
      await _pump(tester, (_, __) async {});
      await tester.enterText(find.byType(TextFormField).at(1), 'x');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pump();
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('show/hide password toggles obscuring', (tester) async {
      await _pump(tester, (_, __) async {});
      EditableText field() => tester.widget<EditableText>(
          find.descendant(
              of: find.byType(TextFormField).at(1),
              matching: find.byType(EditableText)));
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('server error is shown and the button re-enables',
        (tester) async {
      await _pump(tester, (_, __) async => throw Exception('Invalid login'));
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.ensureVisible(_signIn);
      await tester.tap(_signIn);
      await tester.pump();
      await tester.pump();
      expect(find.text('Invalid login'), findsOneWidget);
      expect(_enabled(tester), isTrue);
    });

    testWidgets('fields are disabled while submitting', (tester) async {
      final gate = Future<void>.delayed(const Duration(seconds: 1));
      await _pump(tester, (_, __) => gate.then((_) => throw Exception('no')));
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.ensureVisible(_signIn);
      await tester.tap(_signIn);
      await tester.pump();
      expect(_enabled(tester), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(_enabled(tester), isTrue);
    });
  });
}
