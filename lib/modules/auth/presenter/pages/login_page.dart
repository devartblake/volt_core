import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/user_role.dart';
import '../../state/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/login/login_branding_panel.dart';
import '../widgets/login/login_credentials_form.dart';
import '../widgets/login/login_dev_tools.dart';
import '../widgets/login/login_header.dart';
import '../widgets/login/login_palette.dart';
import '../widgets/login/login_role_picker.dart';
import '../widgets/login/login_validators.dart';

/// Sign-in screen. State and the sign-in calls live here; the pieces are in
/// `widgets/login/`. Authentication itself is unchanged.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  /// Preferred view to open after sign-in. This is only a hint: the server
  /// (`tenant_members`) decides which roles the account actually holds, and a
  /// preference the user doesn't hold is ignored. Defaults to the least
  /// privileged role so the form can never imply an entitlement.
  UserRole _selectedRole = UserRole.tech;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isLoading) return;
    if (!LoginValidators.isValid(_emailCtrl.text, _passwordCtrl.text)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final notifier = ref.read(authStateProvider.notifier);
    try {
      await notifier.login(
        role: _selectedRole,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = LoginValidators.describeError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDevSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final notifier = ref.read(authStateProvider.notifier);
    final wanted = _selectedRole;
    try {
      await notifier.devSignIn(wanted);
      if (!mounted) return;
      final actual = ref.read(authStateProvider).currentRole;
      if (actual != null && actual != wanted) {
        AppSnackBar.info(
          context,
          'That dev account is not a ${wanted.name}; '
          'signed in as ${actual.name}.',
        );
      }
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _errorText =
            'Dev sign-in failed: ${LoginValidators.describeError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      body: isMobile
          ? Container(
              decoration: const BoxDecoration(gradient: LoginPalette.background),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildColumn(auth),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration:
                        const BoxDecoration(gradient: LoginPalette.background),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _buildColumn(auth),
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(flex: 3, child: LoginBrandingPanel()),
              ],
            ),
    );
  }

  Widget _buildColumn(AuthState auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LoginHeader(),
        const SizedBox(height: 40),
        if (auth.isAuthenticated) ...[
          LoginSessionBanner(state: auth),
          const SizedBox(height: 24),
        ],
        if (_errorText != null) ...[
          LoginErrorBanner(message: _errorText!),
          const SizedBox(height: 24),
        ],
        LoginCredentialsForm(
          emailController: _emailCtrl,
          passwordController: _passwordCtrl,
          submitting: _isLoading,
          onSubmit: _onLogin,
        ),
        const SizedBox(height: 32),
        LoginRolePicker(
          selected: _selectedRole,
          enabled: !_isLoading,
          onChanged: (role) => setState(() => _selectedRole = role),
        ),
        if (loginDevToolsAvailable) ...[
          const SizedBox(height: 4),
          LoginDevTools(
            role: _selectedRole,
            enabled: !_isLoading,
            onPressed: _onDevSignIn,
          ),
        ],
        if (auth.isAuthenticated) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              side: BorderSide(color: LoginPalette.white(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Center(
          child: Wrap(
            spacing: 16,
            children: [
              for (final label in const ['Privacy', 'Terms', 'voltcore.app'])
                Text(
                  label,
                  style: loginText(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    alpha: 0.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
