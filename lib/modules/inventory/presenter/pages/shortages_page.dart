import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/app_snack_bar.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/job_needs.dart';
import '../../domain/reorder.dart';
import '../../domain/stock.dart';
import '../../domain/vendor.dart';
import '../../infra/orders_repository.dart';
import '../../infra/pricing_repository.dart';
import '../inventory_access.dart';
import '../job_needs_providers.dart';
import '../widgets/po_review_sheet.dart';

/// What to order: parts jobs need beyond the shelf, and parts running low.
class ShortagesPage extends ConsumerWidget {
  const ShortagesPage({super.key});

  Future<void> _createOrders(
    BuildContext context,
    WidgetRef ref,
    List<ReorderLine> lines,
  ) async {
    final prices = pricesByPart(await ref.read(pricingRepositoryProvider).prices());
    final vendors = await ref.read(pricingRepositoryProvider).vendors();
    final groups = groupByBestVendor(lines, prices);
    if (!context.mounted) return;
    if (groups.isEmpty) {
      AppSnackBar.info(context, 'Everything is already on order.');
      return;
    }
    final n = await showPoReviewSheet(context, ref, groups: groups, vendors: vendors);
    if (n != null && n > 0 && context.mounted) {
      GoRouter.maybeOf(context)?.push(RoutePaths.inventoryOrders);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortages = ref.watch(shortagesProvider);
    final low = ref.watch(lowStockProvider);
    final canManage = ref.watch(canManageInventoryProvider);
    // Orders carry prices, so only admins have them.
    final onOrder = canManage
        ? ref.watch(onOrderProvider).value ?? const <String, int>{}
        : const <String, int>{};

    return AppPage(
      title: 'Shortages',
      body: shortages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Shortages could not be loaded.',
          action: TextButton(
            onPressed: () {
              ref.invalidate(shortagesProvider);
              ref.invalidate(lowStockProvider);
            },
            child: const Text('Retry'),
          ),
        ),
        data: (short) {
          final lowList = low.value ?? const <StockLevel>[];
          if (short.isEmpty && lowList.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nothing to order',
              message: 'Every part the jobs need is covered, and nothing is '
                  'below its minimum.',
            );
          }
          final theme = Theme.of(context);
          final reorder = buildReorderLines(short, lowList, onOrder);
          final toOrder = reorder.where((l) => l.orderQty > 0).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shortagesProvider);
              ref.invalidate(lowStockProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.assignment_late_outlined,
                      label: 'Short for jobs',
                      value: '${short.length}',
                      color: short.isEmpty ? null : theme.colorScheme.error,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatCard(
                      icon: Icons.trending_down,
                      label: 'Low stock',
                      value: '${lowList.length}',
                      color: lowList.isEmpty ? null : theme.colorScheme.tertiary,
                      compact: true,
                    ),
                  ),
                ]),
                if (canManage && reorder.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const Key('create_pos'),
                    onPressed:
                        toOrder.isEmpty ? null : () => _createOrders(context, ref, toOrder),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(toOrder.isEmpty
                        ? 'Everything is on order'
                        : 'Create purchase orders (${toOrder.length})'),
                  ),
                ],
                if (short.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Needed for jobs', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final s in short) _ShortageTile(s: s, onOrder: onOrder),
                ],
                if (lowList.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Below minimum', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final l in lowList) _LowTile(level: l, onOrder: onOrder),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.below,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: below == null
            ? Text(subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  below!,
                ],
              ),
        trailing: trailing,
      ),
    );
  }
}

/// "On order N" under a row's text when open purchase orders cover some.
Widget? _onOrderChip(int onOrder) => onOrder <= 0
    ? null
    : Align(
        alignment: Alignment.centerLeft,
        child: StatusChip(
          key: const Key('on_order_chip'),
          label: 'On order $onOrder',
          tone: StatusTone.info,
        ),
      );

class _ShortageTile extends StatelessWidget {
  const _ShortageTile({required this.s, this.onOrder = const {}});
  final Shortage s;
  final Map<String, int> onOrder;

  @override
  Widget build(BuildContext context) {
    final uncatalogued = s.part == null;
    final ordered = onOrder[s.part?.id] ?? 0;
    final net = shortageOrderQty(s, onOrder);
    return _Tile(
      title: s.partNumber.isEmpty ? 'Unnamed part' : s.partNumber,
      subtitle: [
        if (s.name.isNotEmpty) s.name,
        '${s.jobs} ${s.jobs == 1 ? 'job' : 'jobs'}',
        if (uncatalogued) 'not in catalog' else '${s.available} available',
      ].join(' · '),
      below: _onOrderChip(ordered),
      trailing: StatusChip(
        label: net == 0 && ordered > 0 ? 'Covered' : 'Order $net',
        tone: net == 0 && ordered > 0
            ? StatusTone.success
            : uncatalogued
                ? StatusTone.neutral
                : StatusTone.danger,
      ),
    );
  }
}

class _LowTile extends StatelessWidget {
  const _LowTile({required this.level, this.onOrder = const {}});
  final StockLevel level;
  final Map<String, int> onOrder;

  @override
  Widget build(BuildContext context) {
    final p = level.part;
    return _Tile(
      title: p.partNumber,
      subtitle: '${p.title} · ${level.available} available · minimum ${p.minStock}',
      below: _onOrderChip(onOrder[p.id] ?? 0),
      trailing: StatusChip(
        label: level.onHand <= 0 ? 'Out' : 'Low',
        tone: level.onHand <= 0 ? StatusTone.danger : StatusTone.warning,
      ),
    );
  }
}
