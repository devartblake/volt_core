import 'package:flutter/material.dart';
import '../../domain/user_role.dart';

/// Shared label helper for user roles.
///
/// Import this wherever you need a human-readable label.
String roleLabel(UserRole role) {
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

/// Simple reusable role selector widget used on the login page
/// and any future "switch role" UI.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
    this.enabled = true,
    this.wrapSpacing = 8,
    this.wrapRunSpacing = 8,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;
  final double wrapSpacing;
  final double wrapRunSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: wrapSpacing,
      runSpacing: wrapRunSpacing,
      children: UserRole.values.map((role) {
        final selected = selectedRole == role;
        return ChoiceChip(
          label: Text(roleLabel(role)),
          selected: selected,
          onSelected: !enabled
              ? null
              : (_) {
            onChanged(role);
          },
        );
      }).toList(),
    );
  }
}
