import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/division.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../../infra/division_repository.dart';
import '../controllers/tenant_role_management_controller.dart';
import '../widgets/add_tenant_member_dialog.dart';
import '../widgets/invite_member_sheet.dart';

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

    final divisions = ref.watch(divisionsProvider).value ?? const <Division>[];

    final members = state.members.where((member) {
      if (_roleFilter != null && member.role != _roleFilter) return false;
      if (search.isEmpty) return true;
      return [
        member.displayName,
        member.email,
        member.phone ?? '',
        member.role.name,
        member.role.label,
        divisionNameOf(member.divisionId, divisions) ?? '',
      ].join(' ').toLowerCase().contains(search);
    }).toList();

    return AppPage(
      title: 'Technicians',
      actions: [
        if (auth.isAdmin)
          IconButton(
            tooltip: 'Divisions',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => context.push(RoutePaths.adminDivisions),
          ),
        if (auth.isAdmin)
          TextButton.icon(
            onPressed: () => _invite(context),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Invite'),
          ),
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
      fab: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const AddTenantMemberDialog(),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add member'),
      ),
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
                        child: Text(role.label),
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
                      divisions: divisions,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final outcome = await showInviteMemberSheet(context, ref);
    if (outcome == InviteSheetOutcome.addExisting && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => const AddTenantMemberDialog(),
      );
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.currentUserId,
    this.divisions = const [],
  });

  final TenantMemberEntity member;
  final String? currentUserId;
  final List<Division> divisions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSelf = currentUserId == member.userId;
    final divisionName = divisionNameOf(member.divisionId, divisions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  key: Key('role_chip_${member.userId}'),
                  avatar: const Icon(Icons.badge_outlined, size: 16),
                  label: Text(member.role.label),
                ),
                if (divisionName != null)
                  Chip(
                    key: Key('division_chip_${member.userId}'),
                    avatar: const Icon(Icons.account_tree_outlined, size: 16),
                    label: Text(divisionName),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final roleField = _roleField(context, ref);
                final divisionField = _divisionField(context, ref);
                if (divisionField == null) return roleField;
                if (constraints.maxWidth < 440) {
                  return Column(
                    children: [
                      roleField,
                      const SizedBox(height: 12),
                      divisionField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: roleField),
                    const SizedBox(width: 12),
                    Expanded(child: divisionField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleField(BuildContext context, WidgetRef ref) {
    // DropdownButton (controlled), not a form field: cancelling the confirm
    // dialog must leave the shown role as it was.
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          key: Key('role_dropdown_${member.userId}'),
          value: member.role,
          isExpanded: true,
          isDense: true,
          items: [
            for (final role in UserRole.values)
              DropdownMenuItem(value: role, child: Text(role.label)),
          ],
          onChanged: member.isActive
              ? (newRole) {
                  if (newRole == null || newRole == member.role) return;
                  _confirmRoleChange(context, ref, newRole);
                }
              : null,
        ),
      ),
    );
  }

  /// Null when the division list could not be loaded (offline, or the
  /// divisions migration has not been run), so nothing misleading is shown.
  Widget? _divisionField(BuildContext context, WidgetRef ref) {
    final offered = [
      for (final d in divisions)
        if (d.isActive || d.id == member.divisionId) d,
    ];
    if (divisions.isEmpty && member.divisionId == null) return null;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Division',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
      key: Key('division_dropdown_${member.userId}'),
      value: offered.any((d) => d.id == member.divisionId)
          ? member.divisionId
          : null,
      isExpanded: true,
      isDense: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No division'),
        ),
        for (final d in offered)
          DropdownMenuItem<String?>(
            value: d.id,
            child: Text(
              d.isActive ? d.name : '${d.name} (not offered)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) async {
        if (value == member.divisionId) return;
        final ok = await ref
            .read(tenantRoleManagementControllerProvider.notifier)
            .setDivision(member: member, divisionId: value);
        if (!context.mounted || !ok) return;
        AppSnackBar.success(
          context,
          value == null
              ? '${member.displayName} has no division.'
              : '${member.displayName} is now in '
                  '${divisionNameOf(value, divisions) ?? 'the division'}.',
        );
      },
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
              '${member.displayName}: ${member.role.label} → ${newRole.label}',
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
      AppSnackBar.success(context, '${member.displayName} is now ${newRole.label}.');
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
