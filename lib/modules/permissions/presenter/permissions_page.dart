import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../admin/domain/division.dart';
import '../../admin/domain/entities/tenant_member_entity.dart';
import '../../admin/infra/division_repository.dart';
import '../../admin/presenter/controllers/tenant_role_management_controller.dart';
import '../../admin/presenter/widgets/division_picker.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../domain/permission.dart';
import '../infra/permission_overrides_repository.dart';
import 'permission_providers.dart';

/// What the three choices of one permission mean.
enum _Choice { roleDefault, allow, deny }

_Choice _choiceOf(PermissionEffect? e) => switch (e) {
      null => _Choice.roleDefault,
      PermissionEffect.allow => _Choice.allow,
      PermissionEffect.deny => _Choice.deny,
    };

PermissionEffect? _effectOf(_Choice c) => switch (c) {
      _Choice.roleDefault => null,
      _Choice.allow => PermissionEffect.allow,
      _Choice.deny => PermissionEffect.deny,
    };

const String kPermissionsBannerText =
    'Overrides change what the app lets this person do. Database access is '
    'still set by their role.';

/// Admin: what one person may do, on top of their role. Each permission is
/// Role default, Allow or Deny; changes save at once. Online only.
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  PermissionOverrides? _overrides;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;

  PermissionOverridesRepository get _repo =>
      ref.read(permissionOverridesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      if (ref.read(tenantRoleManagementControllerProvider).members.isEmpty) {
        ref.read(tenantRoleManagementControllerProvider.notifier).load();
      }
      _load();
    });
  }

  String _message(Object e) => e is PermissionsOfflineException
      ? kPermissionsOfflineMessage
      : 'Could not save the change. Try again.';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await _repo.fetchFor(widget.userId);
      if (!mounted) return;
      setState(() {
        _overrides = loaded;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is PermissionsOfflineException
            ? kPermissionsOfflineMessage
            : 'Could not load permissions. Try again.';
      });
    }
  }

  /// Runs a write, then applies [apply] to the shown overrides. If the person
  /// being edited is the signed-in admin, their own cache is refreshed too.
  Future<void> _write(
    Future<void> Function() action,
    PermissionOverrides Function(PermissionOverrides) apply,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => _overrides = apply({...?_overrides}));
      if (ref.read(authStateProvider).userId == widget.userId) {
        await ref.read(permissionOverridesProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(Permission p, _Choice c) {
    final effect = _effectOf(c);
    return _write(
      () => _repo.setOverride(
        userId: widget.userId,
        permission: p,
        effect: effect,
      ),
      (o) {
        if (effect == null) {
          o.remove(p);
        } else {
          o[p] = effect;
        }
        return o;
      },
    );
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all to role default?'),
        content: const Text(
            'Every allow and deny for this person is removed. Their role '
            'decides again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('permissions_reset_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _write(() => _repo.resetAll(widget.userId), (_) => {});
    if (mounted && _loadError == null && _overrides?.isEmpty == true) {
      AppSnackBar.success(context, 'Back to the role defaults.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantRoleManagementControllerProvider);
    final divisions = ref.watch(divisionsProvider).value ?? const <Division>[];
    TenantMemberEntity? member;
    for (final m in state.members) {
      if (m.userId == widget.userId) member = m;
    }

    final Widget body;
    if (member == null) {
      body = state.isLoading || state.members.isEmpty && state.error == null
          ? const Center(child: CircularProgressIndicator())
          : const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Member not found',
              message: 'This person is not on the team.',
            );
    } else {
      body = _content(context, member, divisions);
    }

    return AppPage(title: 'Permissions', body: body);
  }

  Widget _content(
    BuildContext context,
    TenantMemberEntity member,
    List<Division> divisions,
  ) {
    final theme = Theme.of(context);
    final overrides = _overrides ?? const <Permission, PermissionEffect>{};
    final divisionNames = divisionNamesOf(member.divisionIds, divisions);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          member.displayName,
          key: const Key('permissions_member_name'),
          style: theme.textTheme.titleLarge,
        ),
        if (member.email.isNotEmpty) Text(member.email),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              avatar: const Icon(Icons.badge_outlined, size: 16),
              label: Text(member.role.label),
            ),
          ],
        ),
        if (divisionNames.isNotEmpty) ...[
          const SizedBox(height: 4),
          DivisionChips(names: divisionNames, keyPrefix: 'permissions_division'),
        ],
        const SizedBox(height: 12),
        Container(
          key: const Key('permissions_banner'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kPermissionsBannerText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Column(
            key: const Key('permissions_error'),
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 8),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('permissions_retry'),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('permissions_reset_all'),
              onPressed: _busy || overrides.isEmpty ? null : _resetAll,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset all to role default'),
            ),
          ),
          for (final group in PermissionGroup.values) ...[
            const SizedBox(height: 16),
            Text(group.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in Permission.inGroup(group))
              _PermissionRow(
                permission: p,
                member: member,
                effect: overrides[p],
                enabled: !_busy,
                onChoose: (c) => _choose(p, c),
              ),
          ],
        ],
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.member,
    required this.effect,
    required this.enabled,
    required this.onChoose,
  });

  final Permission permission;
  final TenantMemberEntity member;
  final PermissionEffect? effect;
  final bool enabled;
  final ValueChanged<_Choice> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleDefault = permission.defaultFor(member.role);
    final effective = effect == null
        ? roleDefault
        : effect == PermissionEffect.allow;
    final selected = _choiceOf(effect);
    String yn(bool v) => v ? 'Yes' : 'No';

    Widget choice(_Choice c, String label) => ChoiceChip(
          key: Key('perm_choice_${permission.key}_${c.name}'),
          label: Text(label),
          selected: selected == c,
          onSelected: enabled && selected != c ? (_) => onChoose(c) : null,
        );

    return Card(
      key: Key('perm_row_${permission.key}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              permission.label,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(permission.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '${member.role.label} role default: ${yn(roleDefault)}',
              key: Key('perm_default_${permission.key}'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                choice(_Choice.roleDefault, 'Role default'),
                choice(_Choice.allow, 'Allow'),
                choice(_Choice.deny, 'Deny'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              effect == null
                  ? 'Result: ${yn(effective)}'
                  : 'Result: ${yn(effective)} (overridden)',
              key: Key('perm_effective_${permission.key}'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: effective
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
