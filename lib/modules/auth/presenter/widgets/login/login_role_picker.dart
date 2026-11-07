import 'package:flutter/material.dart';

import '../../../domain/user_role.dart';
import '../role_selector.dart' show roleLabel;
import 'login_palette.dart';

/// "Preferred view" divider and role options. A hint only: the server decides
/// which roles the account actually holds.
class LoginRolePicker extends StatelessWidget {
  const LoginRolePicker({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final UserRole selected;
  final bool enabled;
  final ValueChanged<UserRole> onChanged;

  static IconData iconFor(UserRole role) {
    switch (role) {
      case UserRole.tech:
        return Icons.engineering_outlined;
      case UserRole.supervisor:
        return Icons.supervisor_account_outlined;
      case UserRole.dispatcher:
        return Icons.headset_mic_outlined;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: LoginPalette.white(0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'PREFERRED VIEW',
                style: loginText(
                  context,
                  Theme.of(context).textTheme.labelMedium,
                  alpha: 0.5,
                  weight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: LoginPalette.white(0.1))),
          ],
        ),
        const SizedBox(height: 24),
        for (final role in UserRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoleOption(
              icon: iconFor(role),
              label: roleLabel(role),
              selected: selected == role,
              enabled: enabled,
              onTap: () => onChanged(role),
            ),
          ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LoginPalette.white(selected ? 0.1 : 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LoginPalette.white(selected ? 0.4 : 0.1),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: LoginPalette.white(selected ? 0.2 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: LoginPalette.white(selected ? 0.9 : 0.6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: loginText(
                      context,
                      Theme.of(context).textTheme.bodyLarge,
                      alpha: selected ? 0.95 : 0.7,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: LoginPalette.white(0.9),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
