import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/shared/widgets/responsive_scaffold.dart';
import 'package:voltcore/app/app_drawer.dart';
import '../../data/models/maintenance_record.dart';
import '../../providers/maintenance_providers.dart';

class MaintenanceListPage extends ConsumerWidget {
  const MaintenanceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = ref.watch(maintenanceListProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Maintenance Records'),
        elevation: 0,
      ),
      body: list.isEmpty
          ? const _MaintenanceEmpty()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final m = list[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: InkWell(
                onTap: () => context.push('/maintenance/detail/${m.id}'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.build_circle_outlined,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.siteCode.isEmpty
                                      ? 'Maintenance ${m.id}'
                                      : m.siteCode,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_subtitleFor(m).isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _subtitleFor(m),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            tooltip: 'Export PDF',
                            onPressed: () async {
                              final repo = ref.read(maintenanceRepoProvider);
                              await repo.exportMaintenancePdf(m);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('PDF export started'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete maintenance record?'),
                                  content: Text(
                                    m.siteCode.isEmpty
                                        ? 'Are you sure you want to delete this maintenance record? This action cannot be undone.'
                                        : 'Are you sure you want to delete the maintenance record for "${m.siteCode}"? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                final repo = ref.read(maintenanceRepoProvider);
                                await repo.delete(m.id);

                                // Refresh the list
                                ref.read(maintenanceListProvider.notifier).state = repo.getAll();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('Maintenance record deleted'),
                                        ],
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      if (m.address.isNotEmpty ||
                          m.generatorMake.isNotEmpty ||
                          m.dateOfService != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (m.address.isNotEmpty)
                              _InfoChip(
                                icon: Icons.place_outlined,
                                label: m.address,
                              ),
                            if (m.generatorMake.isNotEmpty || m.generatorModel.isNotEmpty)
                              _InfoChip(
                                icon: Icons.settings_outlined,
                                label: '${m.generatorMake} ${m.generatorModel}'.trim(),
                              ),
                            if (m.dateOfService != null)
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                label: m.dateOfService!.toLocal().toString().split(' ').first,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      fab: FloatingActionButton.extended(
        onPressed: () {
          final repo = ref.read(maintenanceRepoProvider);
          final rec = repo.createNew();
          ref.read(maintenanceListProvider.notifier).state = repo.getAll();
          context.push('/maintenance/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Maintenance'),
      ),
      userProfile: const AppUserProfile(
        displayName: 'Field Tech',
        email: 'tech@aselectricnyc.com',
        currentTenant: 'A&S Electric',
        tenants: ['A&S Electric'],
      ),
    );
  }

  String _subtitleFor(MaintenanceRecord m) {
    final parts = <String>[];
    if (m.technicianName.isNotEmpty) {
      parts.add('Tech: ${m.technicianName}');
    }
    if (m.engineHours.isNotEmpty) {
      parts.add('${m.engineHours} hrs');
    }
    return parts.join(' • ');
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceEmpty extends StatelessWidget {
  const _MaintenanceEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_circle_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No maintenance records yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the New Maintenance button to create your first record.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}