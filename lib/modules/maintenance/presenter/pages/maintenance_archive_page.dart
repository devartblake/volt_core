import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_drawer.dart';
import '../../infra/models/maintenance_record.dart';
import '../controllers/maintenance_list_controller.dart';
import '../controllers/maintenance_providers.dart';

class MaintenanceArchivePage extends ConsumerWidget {
  const MaintenanceArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final listState = ref.watch(maintenanceListControllerProvider);
    final archived = listState.records
        .where((m) => m.completed)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Maintenance Records'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref
                  .read(maintenanceListControllerProvider.notifier)
                  .refresh();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Builder(
        builder: (context) {
          if (listState.isLoading && archived.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (archived.isEmpty) {
            return _EmptyArchive(colorScheme: colorScheme, theme: theme);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final m = archived[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () =>
                        context.push('/maintenance/detail/${m.id}'),
                    leading: Icon(
                      Icons.archive_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      m.siteCode.isEmpty
                          ? 'Maintenance ${m.id}'
                          : m.siteCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _buildSubtitle(m),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _buildSubtitle(MaintenanceRecord m) {
    final parts = <String>[];
    if (m.address.isNotEmpty) parts.add(m.address);
    if (m.technicianName.isNotEmpty) {
      parts.add('Tech: ${m.technicianName}');
    }
    if (m.dateOfService != null) {
      parts.add(
        'Service: ${m.dateOfService!.toLocal().toString().split(' ').first}',
      );
    }
    return parts.join(' • ');
  }
}

class _EmptyArchive extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _EmptyArchive({
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.archive_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No archived records yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed maintenance records will appear here.',
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
