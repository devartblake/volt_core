import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../controllers/tenant_role_management_controller.dart';

/// Tenant-authoritative team and role management.
///
/// Authentication and route authorization both read `tenant_members`, so this
/// screen intentionally manages that same source instead of the legacy
/// `technicians.role` column.
class TechniciansPage extends ConsumerStatefulWidget {
  const TechniciansPage({super.key});

  @override
  ConsumerState<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends ConsumerState<TechniciansPage> {
  final _searchController = TextEditingController();
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(tenantRoleManagementControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantRoleManagementControllerProvider);
    final auth = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final search = _searchController.text.trim().toLowerCase();

    final members = state.members.where((member) {
      if (_roleFilter != null && member.role != _roleFilter) return false;
      if (search.isEmpty) return true;
      return [
        member.displayName,
        member.email,
        member.phone ?? '',
        member.role.name,
      ].join(' ').toLowerCase().contains(search);
    }).toList();

    return AppPage(
      title: 'Team & Roles',
      actions: [
        IconButton(
          tooltip: 'Refresh team',
          icon: const Icon(Icons.refresh),
          onPressed: state.isLoading
              ? null
              : () => ref
                  .read(tenantRoleManagementControllerProvider.notifier)
                  .load(),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search tenant members',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<UserRole?>(
                  value: _roleFilter,
                  hint: const Text('Role'),
                  items: [
                    const DropdownMenuItem<UserRole?>(
                      value: null,
                      child: Text('All roles'),
                    ),
                    ...UserRole.values.map(
                      (role) => DropdownMenuItem<UserRole?>(
                        value: role,
                        child: Text(_roleLabel(role)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _roleFilter = value),
                ),
              ],
            ),
          ),
          if (state.error != null)
            MaterialBanner(
              backgroundColor: theme.colorScheme.errorContainer,
              content: Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(tenantRoleManagementControllerProvider.notifier)
                      .load(),
                  child: const Text('Reload'),
                ),
              ],
            ),
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: members.isEmpty && !state.isLoading
                ? const EmptyState(
                    icon: Icons.group_outlined,
                    title: 'No tenant members found',
                    message: 'Active tenant memberships will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _MemberTile(
                      member: members[index],
                      currentUserId: auth.userId,
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
        return 'Technician';
      case UserRole.dispatcher:
        return 'Dispatcher';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.currentUserId});

  final TenantMemberEntity member;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSelf = currentUserId == member.userId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(_initials(member.displayName)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        const Chip(label: Text('You')),
                      ],
                    ],
                  ),
                  if (member.email.isNotEmpty) Text(member.email),
                  Text(
                    member.isActive ? 'Active member' : 'Inactive member',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<UserRole>(
              value: member.role,
              items: UserRole.values
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
              onChanged: member.isActive
                  ? (newRole) {
                      if (newRole == null || newRole == member.role) return;
                      _confirmRoleChange(context, ref, newRole);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRoleChange(
    BuildContext context,
    WidgetRef ref,
    UserRole newRole,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change tenant role?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${member.displayName}: ${member.role.name} → ${newRole.name}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change Role'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !context.mounted) return;

    final auth = ref.read(authStateProvider);
    final actor = auth.userId;
    if (actor == null || actor.isEmpty) return;

    final success = await ref
        .read(tenantRoleManagementControllerProvider.notifier)
        .assignRole(
          member: member,
          newRole: newRole,
          assignedByUserId: actor,
          reason: reason.isEmpty ? null : reason,
        );

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} is now ${newRole.name}.')),
      );
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
