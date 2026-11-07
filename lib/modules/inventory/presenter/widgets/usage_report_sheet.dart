import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../domain/catalog_part.dart';
import '../../domain/stock.dart';
import '../../domain/usage_report.dart';
import '../../domain/vendor.dart';
import '../../infra/inventory_repository.dart';
import '../inventory_access.dart';
import '../movement_providers.dart';

/// Hands a CSV to the system share sheet. A provider so tests can capture it.
typedef UsageCsvExporter = Future<void> Function(String fileName, String csv);

final usageCsvExporterProvider = Provider<UsageCsvExporter>((ref) {
  return (fileName, csv) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      subject: 'Parts usage',
    ));
  };
});

/// The usage report in a full-height sheet (admins and supervisors).
Future<void> showUsageReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.94,
      child: UsageReportView(),
    ),
  );
}

/// Quantities issued (net of returns) by part, manufacturer, month and
/// generator for a chosen period, with CSV export. Admins also see cost
/// (quantity x last price paid).
class UsageReportView extends ConsumerStatefulWidget {
  const UsageReportView({super.key, this.now});

  final DateTime Function()? now;

  @override
  ConsumerState<UsageReportView> createState() => _UsageReportViewState();
}

class _UsageReportViewState extends ConsumerState<UsageReportView> {
  UsagePeriod _period = UsagePeriod.days90;

  UsageReport? _report(
    List<InventoryMovement> ledger,
    List<CatalogPart> parts,
    Map<String, int>? prices,
  ) {
    final now = (widget.now ?? DateTime.now)();
    return computeUsageReport(
      ledger,
      parts,
      from: _period.start(now),
      generatorOf: ref.watch(usageGeneratorsProvider),
      lastPaidCents: prices,
    );
  }

  Future<void> _export(UsageReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = (widget.now ?? DateTime.now)();
    final name = 'parts-usage-${DateFormat('yyyyMMdd').format(now)}.csv';
    try {
      await ref
          .read(usageCsvExporterProvider)(name, usageReportCsv(report));
    } catch (_) {
      AppSnackBar.errorOn(messenger, 'Could not export the report.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCost = ref.watch(canManageInventoryProvider);
    final ledger = ref.watch(ledgerProvider);
    final parts = ref.watch(catalogPartsProvider).value ?? const <CatalogPart>[];
    final prices =
        showCost ? (ref.watch(lastPaidByPartProvider).value ?? const {}) : null;

    return ledger.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState.error(
        message: 'The report could not be loaded.',
        action: TextButton(
          onPressed: () => ref.invalidate(ledgerProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (all) {
        final report = _report(all, parts, prices)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text('Parts usage',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const Key('export_usage_csv'),
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.ios_share),
                  onPressed: report.isEmpty ? null : () => _export(report),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final p in UsagePeriod.values)
                    ChoiceChip(
                      key: Key('usage_period_${p.name}'),
                      label: Text(p.label),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.xl),
            Expanded(
              child: report.isEmpty
                  ? const EmptyState(
                      icon: Icons.bar_chart_outlined,
                      title: 'Nothing issued',
                      message: 'No parts were issued in this period.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                      children: [
                        Row(children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.outbox_outlined,
                              label: 'Issued',
                              value: '${report.totalQty}',
                              compact: true,
                            ),
                          ),
                          if (report.totalCostCents != null) ...[
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: StatCard(
                                icon: Icons.payments_outlined,
                                label: 'Cost',
                                value: formatCents(report.totalCostCents!),
                                compact: true,
                              ),
                            ),
                          ],
                        ]),
                        if (report.totalCostCents != null &&
                            report.unpricedParts > 0)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              '${report.unpricedParts} '
                              '${report.unpricedParts == 1 ? 'part has' : 'parts have'}'
                              ' no price paid on record, so cost is understated.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        _Section(title: 'By part', rows: report.byPart),
                        _Section(
                            title: 'By manufacturer',
                            rows: report.byManufacturer),
                        _Section(
                            title: 'By month',
                            rows: report.byMonth,
                            monthLabels: true),
                        _Section(
                          title: 'By generator',
                          rows: report.byGenerator,
                          footer: report.noGeneratorQty == 0
                              ? null
                              : '${report.noGeneratorQty} issued with no '
                                  'generator',
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

String _monthName(String key) {
  final d = DateTime.tryParse('$key-01');
  return d == null ? key : DateFormat.yMMM().format(d);
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.monthLabels = false,
    this.footer,
  });

  final String title;
  final List<UsageRow> rows;
  final bool monthLabels;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && footer == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthLabels ? _monthName(r.key) : r.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.detail.isNotEmpty)
                        Text(r.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: muted),
                      if (r.jobs > 0)
                        Text('${r.jobs} ${r.jobs == 1 ? 'job' : 'jobs'}',
                            style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r.qty}', style: theme.textTheme.titleSmall),
                    if (r.costCents != null)
                      Text(formatCents(r.costCents!), style: muted),
                  ],
                ),
              ],
            ),
          ),
        if (footer != null) Text(footer!, style: muted),
      ],
    );
  }
}
