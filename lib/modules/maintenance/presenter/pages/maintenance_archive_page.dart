import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../infra/models/maintenance_record.dart';
import '../controllers/maintenance_list_controller.dart';

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

    return AppPage(
      title: 'Archived Maintenance',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.read(maintenanceListControllerProvider.notifier).refresh();
          },
        ),
      ],
      body: Builder(
        builder: (context) {
          if (listState.isLoading && archived.isEmpty) {
            return const LoadingIndicator();
          }

          if (archived.isEmpty) {
            return const EmptyState(
              icon: Icons.archive_outlined,
              title: 'No archived records yet',
              message: 'Completed maintenance records will appear here.',
            );
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

