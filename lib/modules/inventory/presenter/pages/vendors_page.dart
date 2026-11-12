import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/vendor.dart';
import '../../infra/pricing_repository.dart';
import '../inventory_access.dart';
import '../widgets/pricing_sheets.dart';

/// The companies parts are bought from. Admins add and edit them, and record
/// the prices paid from a part's page in Stock.
class VendorsPage extends ConsumerStatefulWidget {
  const VendorsPage({super.key});

  @override
  ConsumerState<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends ConsumerState<VendorsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final n = await ref.read(pricingRepositoryProvider).refreshFromCloud();
        if (n > 0 && mounted) {
          ref.invalidate(vendorsProvider);
          ref.invalidate(allPricesProvider);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorsProvider);
    final prices = ref.watch(allPricesProvider).value ?? const <PartPrice>[];
    final canManage = ref.watch(canManageInventoryProvider);
    final theme = Theme.of(context);

    final counts = <String, int>{};
    for (final p in prices) {
      counts[p.vendorId] = (counts[p.vendorId] ?? 0) + 1;
    }

    return AppPage(
      title: 'Vendors',
      fab: canManage
          ? FloatingActionButton.extended(
              key: const Key('add_vendor'),
              onPressed: () => showVendorEditorSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add vendor'),
            )
          : null,
      body: vendors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Vendors could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(vendorsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No vendors yet',
              message: 'Add the companies you buy generator parts from. Then '
                  'record what each part costs from the part in Stock.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final v = list[i];
              return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.cardAll,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    key: ValueKey('vendor_${v.id}'),
                    onTap: canManage
                        ? () => showVendorEditorSheet(context, ref, vendor: v)
                        : null,
                    title: Text(v.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (v.contact.isNotEmpty) v.contact,
                      if (v.phone.isNotEmpty) v.phone,
                      if (v.email.isNotEmpty) v.email,
                      '${counts[v.id] ?? 0} prices recorded',
                    ].join(' · ')),
                    trailing:
                        v.isActive ? null : const StatusChip(label: 'Inactive'),
                  ),
                );
            },
          );
        },
      ),
    );
  }
}
