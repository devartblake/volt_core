import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../materials/domain/material_item.dart';
import '../../../materials/presenter/job_context_providers.dart';
import '../../domain/catalog_part.dart';
import '../../domain/movement_log.dart';
import '../../domain/movement_paging.dart';
import '../../domain/stock.dart';
import '../../infra/inventory_repository.dart';
import '../movement_providers.dart';
import '../widgets/usage_report_sheet.dart';

StatusTone movementTone(MovementReason r) => switch (r) {
      MovementReason.receive || MovementReason.returned => StatusTone.success,
      MovementReason.issue => StatusTone.warning,
      MovementReason.reserve || MovementReason.release => StatusTone.info,
      MovementReason.adjust ||
      MovementReason.count ||
      MovementReason.transfer =>
        StatusTone.neutral,
    };

/// The stock ledger, newest first, for admins and supervisors. Read-only: a
/// wrong entry is corrected with an offsetting adjustment, never edited.
class MovementsPage extends ConsumerStatefulWidget {
  const MovementsPage({super.key, this.now});

  /// For tests; defaults to the current time.
  final DateTime Function()? now;

  @override
  ConsumerState<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends ConsumerState<MovementsPage> {
  final Set<MovementReason> _reasons = {};
  MovementPeriod _period = MovementPeriod.month;
  String _query = '';
  int _visible = kMovementsPageSize;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final parts = ref.watch(catalogPartsProvider).value ?? const <CatalogPart>[];

    return AppPage(
      title: 'Movements',
      actions: [
        IconButton(
          key: const Key('open_usage_report'),
          tooltip: 'Usage report',
          icon: const Icon(Icons.bar_chart_outlined),
          onPressed: () => showUsageReportSheet(context),
        ),
      ],
      body: ledger.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Movements could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(ledgerProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) => _body(context, all, parts),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<InventoryMovement> all,
    List<CatalogPart> parts,
  ) {
    final byId = {for (final p in parts) p.id: p};
    final shown = filterMovements(
      all,
      parts: byId,
      reasons: _reasons,
      period: _period,
      query: _query,
      now: _now(),
    );
    final page = pageSlice(shown, _visible);
    final days = groupMovementsByDay(page.items);
    final rows = <Object>[
      for (final d in days) ...[d, ...d.movements],
      if (page.hasMore) page,
    ];
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final jobs = ref.watch(jobContextsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ledgerProvider);
        ref.invalidate(catalogPartsProvider);
      },
      child: LazyHeadList(
        padding: const EdgeInsets.all(AppSpacing.lg),
        rowCount: rows.length,
        rowBuilder: (context, i) {
          final r = rows[i];
          if (r is MovementDay) {
            return _DayHeader(day: r.day, count: r.movements.length);
          }
          if (r is PagedSlice) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: OutlinedButton(
                  key: const Key('movements_show_more'),
                  onPressed: () => setState(() => _visible += kMovementsPageSize),
                  child: Text(
                      'Show more (${r.remaining < kMovementsPageSize ? r.remaining : kMovementsPageSize} of ${r.remaining} left)'),
                ),
              ),
            );
          }
          final m = r as InventoryMovement;
          return _MovementTile(
            movement: m,
            part: byId[m.partId],
            who: movementUserLabel(m.userId, names),
            jobs: jobs,
          );
        },
        head: [
          TextField(
            key: const Key('movement_search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search part number, name or maker',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _visible = kMovementsPageSize;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in MovementPeriod.values)
                ChoiceChip(
                  key: Key('period_${p.name}'),
                  label: Text(p.label),
                  selected: _period == p,
                  onSelected: (_) => setState(() {
                    _period = p;
                    _visible = kMovementsPageSize;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final r in MovementReason.values)
                FilterChip(
                  key: Key('reason_${r.wire}'),
                  label: Text(r.label),
                  selected: _reasons.contains(r),
                  onSelected: (on) => setState(() {
                    on ? _reasons.add(r) : _reasons.remove(r);
                    _visible = kMovementsPageSize;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (days.isEmpty)
            EmptyState(
              icon: Icons.swap_vert,
              title: all.isEmpty ? 'No movements yet' : 'Nothing matches',
              message: all.isEmpty
                  ? 'Receipts, adjustments, counts and job issues appear here.'
                  : 'Try a longer period or clear the filters.',
              compact: true,
            )
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        '${DateFormat.yMMMEd().format(day)}  ·  $count',
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.movement,
    required this.part,
    required this.who,
    required this.jobs,
  });

  final InventoryMovement movement;
  final CatalogPart? part;
  final String who;
  final Map<String, JobContext> jobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = movement;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final qty = '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta}';
    final ref = parseJobRef(m.jobRef);
    final job = m.jobRef == null ? null : jobs[m.jobRef];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(part?.partNumber ?? 'Removed part',
                          style: theme.textTheme.titleSmall),
                      if ((part?.name ?? '').isNotEmpty)
                        Text(part!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(qty,
                    key: Key('qty_${m.id}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: m.qtyDelta < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    )),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                    label: m.reason.label, tone: movementTone(m.reason)),
                Text(DateFormat.jm().format(m.at.toLocal()), style: muted),
                Text(who, style: muted),
              ],
            ),
            if (m.note.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(m.note.trim(), style: theme.textTheme.bodySmall),
            ],
            if (m.jobRef != null && m.jobRef!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              if (ref == null)
                Text(m.jobRef!, style: muted)
              else
                InkWell(
                  key: Key('job_${m.id}'),
                  onTap: () => context.push(
                    (ref.type == MaterialOwnerType.inspection
                            ? RoutePaths.inspectionDetail
                            : RoutePaths.maintenanceDetail)
                        .replaceFirst(':id', ref.id),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            job == null
                                ? '${ref.type == MaterialOwnerType.inspection ? 'Inspection' : 'Maintenance'} job'
                                : '${ref.type == MaterialOwnerType.inspection ? 'Inspection' : 'Maintenance'} · ${job.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
