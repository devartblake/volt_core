import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/catalog_part.dart';
import '../../domain/job_cost.dart';
import '../../domain/vendor.dart';
import '../../infra/inventory_repository.dart';
import '../inventory_access.dart';
import '../movement_providers.dart';

/// "Parts cost" for one job (`inspection:ID` / `maintenance:ID`), on the
/// inspection and maintenance screens. Admins only (hard role check, see
/// [canSeeJobCostProvider]); shows nothing for anyone else, or when no parts
/// have been issued to the job. Tap to see the lines.
class JobCostRow extends ConsumerWidget {
  const JobCostRow({super.key, required this.jobRef});

  final String jobRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSeeJobCostProvider)) return const SizedBox.shrink();
    final cost = ref.watch(jobCostsProvider).value?[jobRef];
    if (cost == null || cost.isEmpty) return const SizedBox.shrink();
    final parts =
        ref.watch(catalogPartsProvider).value ?? const <CatalogPart>[];
    return JobCostView(
      jobRef: jobRef,
      cost: cost,
      partsById: {for (final p in parts) p.id: p},
    );
  }
}

/// The presentation of a [JobCost], separate so it can be tested directly.
class JobCostView extends StatelessWidget {
  const JobCostView({
    super.key,
    required this.jobRef,
    required this.cost,
    this.partsById = const {},
  });

  final String jobRef;
  final JobCost cost;
  final Map<String, CatalogPart> partsById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final n = cost.unpricedParts;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: Key('job_cost_row_$jobRef'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const Icon(Icons.payments_outlined),
        title: Text('Parts cost ${formatCents(cost.totalCents)}',
            style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${cost.parts} ${cost.parts == 1 ? 'part' : 'parts'}'
          '${n > 0 ? ' · $n not priced' : ''}',
          style: muted,
        ),
        children: [
          for (final l in cost.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      partsById[l.partId]?.partNumber ?? l.partId,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l.priced
                          ? '${l.qty} × ${formatCents(l.unitCents!)} = '
                              '${formatCents(l.lineCents)}'
                          : '${l.qty} × not priced',
                      textAlign: TextAlign.end,
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
