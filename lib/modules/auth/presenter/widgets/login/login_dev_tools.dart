import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/feature_flags.dart';
import '../../../domain/dev_credentials.dart';
import '../../../domain/user_role.dart';
import 'login_palette.dart';

/// Whether developer sign-in controls may be shown: debug builds only, and
/// only while [FeatureFlags.devLoginBypassEnabled] is on. Release and profile
/// builds never show them, even with the dart-define.
bool get loginDevToolsAvailable =>
    kDebugMode && FeatureFlags.devLoginBypassEnabled;

/// TEMPORARY developer sign-in for the role picked above. With dev credentials
/// configured it is a real Supabase sign-in; otherwise local only.
class LoginDevTools extends StatelessWidget {
  const LoginDevTools({
    super.key,
    required this.role,
    required this.enabled,
    required this.onPressed,
  });

  final UserRole role;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!loginDevToolsAvailable) return const SizedBox.shrink();
    final hasAccount = DevCredentials.forRole(role) != null;
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.bug_report_outlined),
      label: Text(
        hasAccount
            ? 'Dev sign-in as ${role.name}'
            : 'Skip login as ${role.name} (local only, no sync)',
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: LoginPalette.white(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
