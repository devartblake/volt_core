import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/infra/repositories/admin_repository_impl.dart';
import '../domain/job_cost.dart';
import '../domain/short_jobs.dart';
import '../domain/stock.dart';
import '../domain/usage_report.dart';
import '../domain/vendor.dart';
import '../infra/inventory_repository.dart';
import '../infra/pricing_repository.dart';
import '../../materials/presenter/job_context_providers.dart';
import 'job_needs_providers.dart';

/// The whole ledger, newest first.
final ledgerProvider = FutureProvider.autoDispose<List<InventoryMovement>>(
  (ref) => ref.watch(inventoryRepositoryProvider).movements(),
);

/// User id -> name for the company's members. Empty when the list cannot be
/// read (offline, or a role that may not list members); the screen then shows
/// a short id instead.
final memberNamesProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) async {
    try {
      final members =
          await ref.watch(adminRepositoryProvider).listTenantMembers();
      return {
        for (final m in members)
          if (m.displayName.trim().isNotEmpty) m.userId: m.displayName.trim(),
      };
    } catch (_) {
      return const {};
    }
  },
);

/// Job ref -> the generator the job was for (only jobs with one).
final usageGeneratorsProvider =
    Provider.autoDispose<Map<String, UsageGenerator>>((ref) {
  final jobs = ref.watch(jobContextsProvider);
  return {
    for (final j in jobs.values)
      if (j.generatorKey.isNotEmpty)
        j.jobRef: UsageGenerator(
          key: j.generatorKey,
          label: j.generatorLabel.isEmpty ? j.title : j.generatorLabel,
        ),
  };
});

/// Part id -> last price paid, in cents. Prices are admin-only: callers only
/// watch this for admins.
final lastPaidByPartProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final prices = await ref.watch(allPricesProvider.future);
  final out = <String, int>{};
  pricesByPart(prices).forEach((partId, list) {
    final last = summarizePrices(list).lastPaid;
    if (last != null) out[partId] = last.unitCents;
  });
  return out;
});

/// Parts cost of each job that has parts issued, at the last price paid,
/// worked out on the device from the ledger and prices it already holds.
/// Admin only: callers watch this only for admins.
final jobCostsProvider =
    FutureProvider.autoDispose<Map<String, JobCost>>((ref) async {
  final ledger = await ref.watch(ledgerProvider.future);
  final paid = await ref.watch(lastPaidByPartProvider.future);
  return computeJobCosts(ledger, paid);
});

/// How many jobs are short of parts, for the dashboard.
final jobsShortOfPartsProvider = FutureProvider.autoDispose<int>((ref) async {
  final needs = await ref.watch(jobNeedsProvider.future);
  return jobsShortOfParts(needs);
});
