import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@gmail.com');
  final _nameCtrl = TextEditingController(text: 'Admin');
  UserRole _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authStateProvider.notifier);
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    notifier.login(
      role: _selectedRole,
      email: email,
      displayName: name.isEmpty ? null : name,
    );

    // Go to dashboard after login
    context.go('/');
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

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                return 'Please enter an email for this demo.';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role selector
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Role',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: UserRole.values.map((role) {
                              final selected = _selectedRole == role;
                              return ChoiceChip(
                                label: Text(_roleLabel(role)),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedRole = role;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _onLogin,
                              icon: const Icon(Icons.login),
                              label: Text(
                                  'Login as ${_roleLabel(_selectedRole)}'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (auth.isAuthenticated)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final controller =
                                  ref.read(authStateProvider.notifier);
                                  controller.logout();
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

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.tech:
        return 'Tech';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.dispatcher:
        return 'Dispatcher';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class _CurrentSessionBanner extends StatelessWidget {
  const _CurrentSessionBanner({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final roleLabel = state.currentRole != null
        ? _roleLabel(state.currentRole!)
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
              'Signed in as $roleLabel'
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

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.tech:
        return 'Tech';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.dispatcher:
        return 'Dispatcher';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
