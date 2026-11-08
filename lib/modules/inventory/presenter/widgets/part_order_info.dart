import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/vendor.dart';
import '../../infra/orders_repository.dart';

/// For a part's sheet (admins): how many are on order, and its recent
/// purchase order lines - vendor, quantity, price, date and PO number.
class PartOrderInfo extends ConsumerWidget {
  const PartOrderInfo({
    super.key,
    required this.partId,
    required this.vendorNames,
  });

  final String partId;
  final Map<String, String> vendorNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onOrder = ref.watch(onOrderProvider).value?[partId] ?? 0;
    final history =
        ref.watch(partOrderHistoryProvider(partId)).value ?? const [];
    if (onOrder <= 0 && history.isEmpty) return const SizedBox.shrink();
    final fmt = DateFormat('MMM d, y');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOrder > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('On order $onOrder',
                key: const Key('part_on_order'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Reorder history', style: theme.textTheme.titleSmall),
          for (final h in history.take(5))
            ListTile(
              key: ValueKey('reorder_${h.line.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                  '${h.line.qtyOrdered} from ${vendorNames[h.order.vendorId] ?? 'vendor'}'
                  '${h.line.unitCents > 0 ? ' @ ${formatCents(h.line.unitCents)}' : ''}'),
              subtitle: Text([
                h.order.displayNumber,
                fmt.format(h.order.createdAt.toLocal()),
                h.order.status.label,
                if (h.line.qtyReceived > 0) '${h.line.qtyReceived} received',
              ].join(' · ')),
            ),
        ],
      ],
    );
  }
}
