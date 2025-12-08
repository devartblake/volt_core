import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/user_role.dart';
import '../../state/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/role_selector.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController(text: 'admin@gmail.com');
  final _nameCtrl = TextEditingController(text: 'Admin');
  final _passwordCtrl = TextEditingController(text: 'password123'); // demo

  UserRole _selectedRole = UserRole.admin;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final notifier = ref.read(authStateProvider.notifier);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      await notifier.login(
        role: _selectedRole,
        email: email,
        password: password,
      );

      if (mounted) {
        // GoRouter redirect will also see isAuthenticated == true
        // and send you away from /login, but this keeps UX snappy.
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorText = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 48,
                      color: color.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Voltcore Access',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in with a role to continue',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Already logged in summary
                    if (auth.isAuthenticated) ...[
                      _CurrentSessionBanner(state: auth),
                      const SizedBox(height: 16),
                    ],

                    if (_errorText != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Name (optional)
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) {
                                return 'Please enter an email.';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) {
                                return 'Please enter a password.';
                              }
                              if (v.length < 4) {
                                return 'Password is too short for this demo.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role selector label
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Role',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🔹 Reusable RoleSelector widget
                          RoleSelector(
                            selectedRole: _selectedRole,
                            enabled: !_isLoading,
                            onChanged: (role) {
                              setState(() {
                                _selectedRole = role;
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _onLogin,
                              icon: _isLoading
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.login),
                              label: Text(
                                _isLoading
                                    ? 'Signing in...'
                                    : 'Login as ${roleLabel(_selectedRole)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Logout (when already authenticated)
                          if (auth.isAuthenticated)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                  final controller = ref.read(
                                      authStateProvider.notifier);
                                  await controller.logout();
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Logout'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentSessionBanner extends StatelessWidget {
  const _CurrentSessionBanner({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final roleText = state.currentRole != null
        ? roleLabel(state.currentRole!)
        : 'Unknown';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: color.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Signed in as $roleText'
                  '${state.email != null ? ' • ${state.email}' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
