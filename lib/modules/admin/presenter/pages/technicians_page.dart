import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/technician_entity.dart';
import '../controllers/role_management_controller.dart';

/// Dedicated technicians / role management screen.
///
/// - Loads technicians via [roleManagementControllerProvider]
/// - Lets admin change roles inline with a dropdown
/// - Uses the current logged-in admin's userId (authStateProvider)
class TechniciansPage extends ConsumerStatefulWidget {
  const TechniciansPage({super.key});

  @override
  ConsumerState<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends ConsumerState<TechniciansPage> {
  final _searchCtrl = TextEditingController();
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    // Load technicians when screen mounts
    Future.microtask(() {
      ref.read(roleManagementControllerProvider.notifier).loadTechnicians();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleManagementControllerProvider);
    final auth = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final search = _searchCtrl.text.trim().toLowerCase();

    // Apply search + role filter on client side
    final filtered = state.technicians.where((t) {
      if (_roleFilter != null && t.role != _roleFilter) return false;
      if (search.isEmpty) return true;

      final haystack = [
        t.name,
        t.email ?? '',
        t.phone ?? '',
        t.role.name,
      ].join(' ').toLowerCase();

      return haystack.contains(search);
    }).toList();

    final assignedByUserId = auth.userId ?? auth.email ?? 'admin-local';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technicians & Roles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: () {
              ref
                  .read(roleManagementControllerProvider.notifier)
                  .loadTechnicians();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters / search row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search technicians',
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
                          (r) => DropdownMenuItem<UserRole?>(
                        value: r,
                        child: Text(_roleLabel(r)),
                      ),
                    )
                  ],
                  onChanged: (value) {
                    setState(() {
                      _roleFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),

          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: MaterialBanner(
                backgroundColor: color.errorContainer,
                content: Text(
                  state.error!,
                  style: TextStyle(color: color.onErrorContainer),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      ref
                          .read(roleManagementControllerProvider.notifier)
                          .loadTechnicians();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          if (state.isLoading)
            const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: filtered.isEmpty && !state.isLoading
                ? const _EmptyState()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tech = filtered[index];
                return _TechnicianTile(
                  technician: tech,
                  assignedByUserId: assignedByUserId,
                );
              },
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

class _TechnicianTile extends ConsumerWidget {
  const _TechnicianTile({
    required this.technician,
    required this.assignedByUserId,
  });

  final TechnicianEntity technician;
  final String assignedByUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.primaryContainer,
              child: Text(
                _initials(technician.name),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    technician.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (technician.email != null) technician.email!,
                      if (technician.phone != null) technician.phone!,
                    ].join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Role: ${technician.role.name} • '
                        'Active: ${technician.isActive ? 'Yes' : 'No'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<UserRole>(
              value: technician.role,
              underline: const SizedBox.shrink(),
              items: UserRole.values.map((r) {
                return DropdownMenuItem<UserRole>(
                  value: r,
                  child: Text(_roleShortLabel(r)),
                );
              }).toList(),
              onChanged: (newRole) {
                if (newRole == null || newRole == technician.role) return;

                ref
                    .read(roleManagementControllerProvider.notifier)
                    .assignRoleToTech(
                  technician: technician,
                  newRole: newRole,
                  assignedByUserId: assignedByUserId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String _roleShortLabel(UserRole role) {
    switch (role) {
      case UserRole.tech:
        return 'Tech';
      case UserRole.supervisor:
        return 'Sup.';
      case UserRole.dispatcher:
        return 'Disp.';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering_outlined,
              size: 40,
              color: color.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No technicians found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Once technicians are synced from Supabase, they will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
