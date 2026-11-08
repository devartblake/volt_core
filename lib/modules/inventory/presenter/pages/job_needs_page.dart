import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/job_needs.dart';
import '../../domain/vendor.dart' show formatCents;
import '../../infra/inventory_repository.dart';
import '../inventory_access.dart';
import '../job_needs_providers.dart';
import '../movement_providers.dart';

StatusTone toneFor(NeedStatus s) => switch (s) {
      NeedStatus.issued || NeedStatus.reserved || NeedStatus.available =>
        StatusTone.success,
      NeedStatus.partial => StatusTone.warning,
      NeedStatus.short => StatusTone.danger,
      NeedStatus.notInCatalog => StatusTone.neutral,
    };

enum _Act { reserve, release, issue, giveBack }

/// The parts each job has flagged as needed, and whether the warehouse can
/// cover them. Supervisors, dispatchers and admins set parts aside, issue them
/// and take returns; technicians can look.
class JobNeedsPage extends ConsumerWidget {
  const JobNeedsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needs = ref.watch(jobNeedsProvider);
    final canAct = ref.watch(canReserveStockProvider);

    return AppPage(
      title: 'Job Needs',
      body: needs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Job needs could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(jobNeedsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No parts needed',
              message: 'Parts marked "Needs replacement" on an inspection, '
                  'and the parts listed on open maintenance, appear here '
                  'with what the warehouse has for them.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(jobNeedsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: jobs.length,
              itemBuilder: (context, i) =>
                  _JobCard(job: jobs[i], canAct: canAct),
            ),
          );
        },
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.canAct});

  final JobNeeds job;
  final bool canAct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final j = job.job;
    // Costs are admin-only data, like prices.
    final isAdmin = ref.watch(canManageInventoryProvider);
    final costs = isAdmin ? ref.watch(jobCostsProvider).value : null;
    final cost = costs == null ? null : costs[j.jobRef];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.title, style: theme.textTheme.titleMedium),
                    Text(j.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (job.isCovered)
                const StatusChip(label: 'Covered', tone: StatusTone.success)
              else if (job.shortCount > 0)
                StatusChip(
                    label: '${job.shortCount} short', tone: StatusTone.danger),
              IconButton(
                tooltip: 'Open the job',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => context.push(j.type.wire == 'inspection'
                    ? RoutePaths.inspectionDetail.replaceFirst(':id', j.id)
                    : RoutePaths.maintenanceDetail.replaceFirst(':id', j.id)),
              ),
            ]),
            if (cost != null && !cost.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Parts cost ${formatCents(cost.totalCents)}'
                  '${cost.unpricedParts > 0 ? ' · ${cost.unpricedParts} ${cost.unpricedParts == 1 ? 'part' : 'parts'} not priced' : ''}',
                  key: Key('job_cost_${j.jobRef}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const Divider(height: AppSpacing.xl),
            for (final l in job.lines) _LineRow(line: l, canAct: canAct),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.line, required this.canAct});

  final NeedLine line;
  final bool canAct;

  List<_Act> get _actions {
    final p = line.part;
    if (p == null) return const [];
    return [
      if (line.outstanding > 0 && line.available > 0) _Act.reserve,
      if (line.reserved > 0) _Act.issue,
      if (line.reserved > 0) _Act.release,
      if (line.issued > 0) _Act.giveBack,
    ];
  }

  Future<void> _do(BuildContext context, WidgetRef ref, _Act a) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final part = line.part!;
    final ref0 = line.jobRef;
    try {
      switch (a) {
        case _Act.reserve:
          final n = line.outstanding < line.available
              ? line.outstanding
              : line.available;
          await repo.reserveForJob(ref0, part.id, n);
          AppSnackBar.successOn(messenger, 'Reserved $n × ${part.partNumber}');
        case _Act.release:
          await repo.releaseForJob(ref0, part.id, line.reserved);
          AppSnackBar.successOn(messenger, 'Reservation released');
        case _Act.issue:
          await repo.issueToJob(ref0, part.id, line.reserved,
              fromReserved: line.reserved);
          AppSnackBar.successOn(
              messenger, 'Issued ${line.reserved} × ${part.partNumber}');
        case _Act.giveBack:
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Return parts?'),
              content: Text(
                  'Put ${line.issued} × ${part.partNumber} back in the warehouse.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Return')),
              ],
            ),
          );
          if (ok != true) return;
          await repo.returnFromJob(ref0, part.id, line.issued);
          AppSnackBar.successOn(messenger, 'Returned to the warehouse');
      }
      ref.invalidate(jobNeedsProvider);
      ref.invalidate(stockLevelsProvider);
      ref.invalidate(partMovementsProvider);
    } catch (_) {
      AppSnackBar.errorOn(messenger, 'Could not save. Try again.');
    }
  }

  static String _label(_Act a) => switch (a) {
        _Act.reserve => 'Reserve',
        _Act.release => 'Release',
        _Act.issue => 'Issue',
        _Act.giveBack => 'Return',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = line.item;
    final p = line.part;
    final title = item.partNumber.trim().isEmpty
        ? (item.partName.isEmpty ? item.slot.label : item.partName)
        : item.partNumber;
    final detail = [
      item.slot.label,
      if (p != null && p.name.isNotEmpty) p.name else if (item.partName.isNotEmpty) item.partName,
      if (line.usingAlternate) 'using alternate ${p!.partNumber}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${line.required} × $title',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                if (line.status == NeedStatus.partial ||
                    line.status == NeedStatus.short)
                  Text('${line.available} available',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          StatusChip(label: line.status.label, tone: toneFor(line.status)),
          if (canAct && _actions.isNotEmpty)
            PopupMenuButton<_Act>(
              key: ValueKey('actions-${item.id}'),
              tooltip: 'Actions',
              onSelected: (a) => _do(context, ref, a),
              itemBuilder: (_) => [
                for (final a in _actions)
                  PopupMenuItem(value: a, child: Text(_label(a))),
              ],
            ),
        ],
      ),
    );
  }
}
