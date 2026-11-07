import 'package:flutter/material.dart';

import '../role_selector.dart' show roleLabel;
import '../../../state/auth_state.dart';
import 'login_palette.dart';

/// "SIGN IN" badge, welcome heading and subtitle.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: LoginPalette.white(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LoginPalette.white(0.2)),
          ),
          child: Text(
            'SIGN IN',
            style: loginText(
              context,
              text.labelSmall,
              alpha: 0.9,
              weight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Welcome!',
          style: loginText(
            context,
            text.displaySmall,
            weight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sign in with your credentials to access Voltcore inspection and '
          'maintenance management.',
          style: loginText(context, text.bodyLarge, alpha: 0.7, height: 1.5),
        ),
      ],
    );
  }
}

/// Banner showing a sign-in problem (server error or dev sign-in failure).
class LoginErrorBanner extends StatelessWidget {
  const LoginErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: LoginPalette.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: LoginPalette.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner for an already signed-in session.
class LoginSessionBanner extends StatelessWidget {
  const LoginSessionBanner({super.key, required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final role =
        state.currentRole != null ? roleLabel(state.currentRole!) : 'Unknown';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.blue[300], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Signed in as $role'
              '${state.email != null ? ' • ${state.email}' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.blue[100]),
            ),
          ),
        ],
      ),
    );
  }
}
