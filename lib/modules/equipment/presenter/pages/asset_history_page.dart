import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../infra/repositories/equipment_repository_impl.dart';

/// The local inspection timeline for one physical asset.
///
/// The registry itself is derived from local inspections, so this remains
/// usable offline and deliberately does not pretend that a remote query has
/// succeeded. The repository is the seam where shared history can be merged
/// in once the tracked Supabase schema is available.
final assetInspectionHistoryProvider =
    FutureProvider.autoDispose.family<List<InspectionEntity>, String>(
      (ref, assetId) async {
        final assets = await ref.watch(equipmentListProvider.future);
        final asset = _assetById(assets, assetId);
        if (asset == null) return const [];
        return ref
            .watch(equipmentRepositoryProvider)
            .listInspectionHistory(asset.toEntity());
      },
    );

class AssetHistoryPage extends ConsumerWidget {
  const AssetHistoryPage({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(equipmentListProvider);

    return assets.when(
      loading: () => const AppPage(
        title: 'Asset history',
        body: LoadingIndicator(),
      ),
      error: (error, _) => AppPage(
        title: 'Asset history',
        body: EmptyState.error(
          title: 'Could not load asset history',
          message: '$error',
        ),
      ),
      data: (items) {
        final asset = _assetById(items, assetId);
        if (asset == null) {
          return const AppPage(
            title: 'Asset history',
            body: EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Asset not found',
              message: 'This asset is no longer available in the registry.',
            ),
          );
        }

        final history = ref.watch(assetInspectionHistoryProvider(assetId));
        return AppPage(
          title: 'Asset history',
          leading: BackButton(onPressed: () => context.pop()),
          body: Column(
            children: [
              _AssetSummary(
                name: asset.name,
                make: asset.make,
                model: asset.model,
                serial: asset.serialNumber,
                siteCode: asset.siteCode,
              ),
              Expanded(
                child: history.when(
                  loading: () => const LoadingIndicator(),
                  error: (error, _) => EmptyState.error(
                    title: 'Could not load inspection history',
                    message: '$error',
                  ),
                  data: (records) {
                    if (records.isEmpty) {
                      return const EmptyState(
                        icon: Icons.history_toggle_off_outlined,
                        title: 'No local inspection history',
                        message:
                            'Inspections collected on this device will appear here.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _InspectionHistoryTile(
                        record: records[index],
                        onTap: () => context.push(
                          '/inspections/detail/${records[index].id}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssetSummary extends StatelessWidget {
  const _AssetSummary({
    required this.name,
    required this.make,
    required this.model,
    required this.serial,
    required this.siteCode,
  });

  final String name;
  final String make;
  final String model;
  final String serial;
  final String siteCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final details = [
      if (make.trim().isNotEmpty || model.trim().isNotEmpty)
        [make, model].where((item) => item.trim().isNotEmpty).join(' '),
      if (serial.trim().isNotEmpty) 'Serial: $serial',
      if (siteCode.trim().isNotEmpty) 'Site: $siteCode',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: const Icon(Icons.precision_manufacturing_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionHistoryTile extends StatelessWidget {
  const _InspectionHistoryTile({required this.record, required this.onTap});

  final InspectionEntity record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeColor = _gradeColor(record.siteGrade, theme.colorScheme);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: gradeColor.withValues(alpha: 0.15),
          foregroundColor: gradeColor,
          child: const Icon(Icons.fact_check_outlined),
        ),
        title: Text(_formatDate(record.serviceDate)),
        subtitle: Text(
          [
            if (record.technicianName.trim().isNotEmpty)
              record.technicianName.trim(),
            if (record.address.trim().isNotEmpty) record.address.trim(),
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GradeChip(grade: record.siteGrade, color: gradeColor),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade, required this.color});

  final String grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = grade.trim().isEmpty ? 'Unrated' : grade.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _gradeColor(String grade, ColorScheme colors) {
  switch (grade.trim().toLowerCase()) {
    case 'green':
      return Colors.green.shade700;
    case 'amber':
      return Colors.amber.shade800;
    case 'red':
      return colors.error;
    default:
      return colors.onSurfaceVariant;
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

Equipment? _assetById(List<Equipment> assets, String assetId) {
  for (final asset in assets) {
    if (asset.id == assetId) return asset;
  }
  return null;
}
