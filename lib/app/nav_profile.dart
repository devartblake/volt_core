import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/auth/domain/user_role.dart';
import '../modules/auth/presenter/controllers/auth_controller.dart';

/// User profile model
class AppUserProfile {
  final String displayName;
  final String email;
  final String? avatarUrl;

  /// Active tenant name, or null when none is known yet (still loading, or the
  /// account has no tenant membership). The UI omits the row rather than
  /// showing a placeholder.
  final String? currentTenant;
  final List<String> tenants;
  final String? role; // Optional user role label

  const AppUserProfile({
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.currentTenant,
    this.tenants = const [],
    this.role,
  });
}

/// Profile footer for drawer
class ProfileFooter extends ConsumerWidget {
  const ProfileFooter(this.profile, this.onSwitchTenant, {super.key});

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final auth = ref.watch(authStateProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Icon(
                  Icons.person_outline,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.role != null)
                    _RoleLine(
                      role: auth.currentRole,
                      grantedRoles: auth.grantedRoles,
                      label: profile.role!,
                    ),
                  Text(
                    profile.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (profile.currentTenant != null)
                  Row(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.currentTenant!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.tenants.length > 1)
                        IconButton(
                          icon:
                          const Icon(Icons.swap_horiz, size: 20),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => _TenantSwitcher(
                                profile: profile,
                                onSwitchTenant: onSwitchTenant,
                              ),
                            );
                          },
                          tooltip: 'Switch tenant',
                          // Keep the 48dp minimum — this is a gloved,
                          // outdoors app; the zeroed constraints it had
                          // before made the target ~20dp.
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: kMinInteractiveDimension,
                            minHeight: kMinInteractiveDimension,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current role, tappable when the account holds more than one.
///
/// Roles come from the server (`tenant_members`); this only chooses which of
/// the user's own grants the session acts as, and [AuthController.switchRole]
/// refuses anything not granted.
class _RoleLine extends ConsumerWidget {
  const _RoleLine({
    required this.role,
    required this.grantedRoles,
    required this.label,
  });

  final UserRole? role;
  final Set<UserRole> grantedRoles;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w500,
    );

    // Single-role accounts (the common case) just read the role.
    if (grantedRoles.length < 2) {
      return Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _RoleSwitcher(
          current: role,
          granted: grantedRoles,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the roles this account actually holds.
class _RoleSwitcher extends ConsumerWidget {
  const _RoleSwitcher({required this.current, required this.granted});

  final UserRole? current;
  final Set<UserRole> granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Most privileged first, so the common "act as admin" is at the top.
    final roles = granted.toList()
      ..sort((a, b) => b.privilege.compareTo(a.privilege));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Act as',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Switching changes which screens are available. Your access is '
              'set by your organisation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final role in roles)
            ListTile(
              leading: Icon(
                role == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: role == current ? theme.colorScheme.primary : null,
              ),
              title: Text(role.label),
              onTap: () {
                ref.read(authStateProvider.notifier).switchRole(role);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tenant switcher bottom sheet
class _TenantSwitcher extends StatelessWidget {
  const _TenantSwitcher({
    required this.profile,
    required this.onSwitchTenant,
  });

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apartment_outlined,
                  color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Switch Tenant',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...profile.tenants.map((tenant) {
            final isSelected = tenant == profile.currentTenant;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                tenant,
                style: TextStyle(
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                onSwitchTenant?.call(tenant);
                Navigator.of(context).pop();
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Profile mini for rail
class ProfileMini extends StatelessWidget {
  const ProfileMini(this.profile, this.onSwitchTenant, {super.key});

  final AppUserProfile profile;
  final ValueChanged<String>? onSwitchTenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Icon(
              Icons.person_outline,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        if (profile.tenants.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Switch tenant',
            icon: Icon(
              Icons.swap_horiz,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            onSelected: (t) => onSwitchTenant?.call(t),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (ctx) => [
              for (final t in profile.tenants)
                PopupMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(
                        t == profile.currentTenant
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: t == profile.currentTenant
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t,
                        style: TextStyle(
                          fontWeight: t == profile.currentTenant
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
