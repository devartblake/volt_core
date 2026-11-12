import 'package:flutter/material.dart';
import '../utils/maintenance_pdf_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';
import '../../domain/maintenance_progress.dart';
import '../../infra/models/maintenance_record.dart';
import '../controllers/maintenance_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class MaintenanceDetailPage extends ConsumerWidget {
  final String id;

  const MaintenanceDetailPage({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = ref.watch(maintenanceRepoProvider);
    final rec = repo.getById(id);

    if (rec == null) {
      return AppPage(
      title: 'Maintenance Detail',
      body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Record not found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.go('/maintenance'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Maintenance List'),
              ),
            ],
          ),
        ),
    );
    }

    return AppPage(
      title: '',
      titleWidget: Text(rec.siteCode.isEmpty ? 'Maintenance Detail' : rec.siteCode),
      actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 12),
                    Text('Delete'),
                  ],
                ),
                onTap: () async {
                  // Delay to allow menu to close
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (!context.mounted) return;

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete maintenance record?'),
                      content: const Text(
                        'This action cannot be undone. All data for this maintenance record will be permanently deleted.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await repo.delete(id);

                    // Refresh list provider
                    ref.read(maintenanceListProvider.notifier).state =
                        repo.getAll();

                    if (context.mounted) {
                      context.go('/maintenance');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _DetailBody(rec: rec),
      ),
      // The things you do with a finished record stay in reach while reading
      // a long one, instead of icons at the top of the screen.
      bottomBar: _DetailActionBar(
        rec: rec,
        onEdit: () => context.push('/maintenance/new?id=$id'),
        onPrint: () => printMaintenancePdfWithFeedback(context, repo, rec),
        onExport: () => exportMaintenancePdfWithFeedback(context, repo, rec),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final MaintenanceRecord rec;

  const _DetailBody({required this.rec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryHeader(rec: rec),
        const SizedBox(height: 16),

        // Site & Generator Info
        _SectionCard(
          title: 'Site & Generator Information',
          icon: Icons.location_on_outlined,
          children: [
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Technician',
              value: rec.technicianName,
            ),
            _InfoRow(
              icon: Icons.settings_outlined,
              label: 'Generator',
              value: '${rec.generatorMake} ${rec.generatorModel}'.trim(),
            ),
            _InfoRow(
              icon: Icons.tag_outlined,
              label: 'Serial Number',
              value: rec.generatorSerial,
            ),
            _InfoRow(
              icon: Icons.bolt_outlined,
              label: 'Voltage',
              value: rec.voltageRating,
            ),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Engine Hours',
              value: rec.engineHours,
            ),
            _InfoRow(
              icon: Icons.local_gas_station_outlined,
              label: 'Fuel Type',
              value: rec.fuelType,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Actions Performed
        if (_hasActionsPerformed(rec)) ...[
          _SectionCard(
            title: 'Actions Performed',
            icon: Icons.build_outlined,
            children: [
              if (rec.oilFilterChanged)
                _ActionChip(
                  label: 'Oil filter changed',
                  notes: rec.oilFilterNotes,
                ),
              if (rec.fuelFilterReplaced)
                _ActionChip(
                  label: 'Fuel filter replaced',
                  notes: rec.fuelFilterNotes,
                ),
              if (rec.coolantFlushed)
                _ActionChip(
                  label: 'Coolant flushed',
                  notes: rec.coolantNotes,
                ),
              if (rec.batteryReplaced)
                _ActionChip(
                  label: 'Battery replaced',
                  notes: rec.batteryNotes,
                ),
              if (rec.airFilterReplaced)
                _ActionChip(
                  label: 'Air filter replaced',
                  notes: rec.airFilterNotes,
                ),
              if (rec.beltsHosesReplaced)
                _ActionChip(
                  label: 'Belts/hoses replaced',
                  notes: rec.beltsHosesNotes,
                ),
              if (rec.blockHeaterTested)
                _ActionChip(
                  label: 'Block heater tested',
                  notes: rec.blockHeaterNotes,
                ),
              if (rec.racorServiced)
                _ActionChip(
                  label: 'Racor serviced',
                  notes: rec.racorNotes,
                ),
              if (rec.atsControllerInspected)
                _ActionChip(
                  label: 'ATS/controller inspected',
                  notes: rec.atsControllerNotes,
                ),
              if (rec.cdvrProgrammed)
                _ActionChip(
                  label: 'CDVR programmed',
                  notes: rec.cdvrNotes,
                ),
              if (rec.undervoltageRepaired)
                _ActionChip(
                  label: 'Under-voltage repaired',
                  notes: rec.undervoltageNotes,
                ),
              if (rec.hazmatRemoved)
                _ActionChip(
                  label: 'Hazmat removed',
                  notes: rec.hazmatNotes,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Service Observations
        if (rec.serviceObservations.isNotEmpty) ...[
          _SectionCard(
            title: 'Service Observations',
            icon: Icons.notes_outlined,
            children: [
              Text(
                rec.serviceObservations,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Post-Service Checklist Summary
        if (_hasPostServiceItems(rec)) ...[
          _SectionCard(
            title: 'Post-Service Checklist',
            icon: Icons.task_alt_outlined,
            children: [
              if (rec.postVerifyRunsUnderLoad)
                const _ChecklistItem(
                    label: 'Generator runs under load'),
              if (rec.postCheckVoltFreq)
                const _ChecklistItem(
                    label: 'Voltage & frequency checked'),
              if (rec.postInspectExhaust)
                const _ChecklistItem(label: 'Exhaust system inspected'),
              if (rec.postVerifyGrounding)
                const _ChecklistItem(
                    label: 'Grounding & bonding verified'),
              if (rec.postCheckControlPanel)
                const _ChecklistItem(label: 'Control panel checked'),
              if (rec.postEnsureSafetyDevices)
                const _ChecklistItem(
                    label: 'Safety devices functional'),
              if (rec.postDocumentDeficiencies)
                const _ChecklistItem(
                    label: 'Deficiencies documented'),
              if (rec.postLoadbankTest)
                const _ChecklistItem(label: 'Load-bank test performed'),
              if (rec.postAtsFunctionality)
                const _ChecklistItem(
                    label: 'ATS functionality verified'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Signatures
        if (rec.technicianSignatureName.isNotEmpty ||
            rec.customerSignatureName.isNotEmpty) ...[
          _SectionCard(
            title: 'Signatures',
            icon: Icons.draw_outlined,
            children: [
              if (rec.technicianSignatureName.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.engineering_outlined,
                  label: 'Technician',
                  value: rec.technicianSignatureName,
                ),
                if (rec.technicianSignatureDate != null)
                  Padding(
                    padding:
                    const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      'Signed: ${_fmtDate(rec.technicianSignatureDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (rec.customerSignatureName.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.business_outlined,
                  label: 'Customer',
                  value: rec.customerSignatureName,
                ),
                if (rec.customerSignatureDate != null)
                  Padding(
                    padding:
                    const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      'Signed: ${_fmtDate(rec.customerSignatureDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Photos taken during the service (stored apart from the record).
        PhotoAttachmentsSection(
          ownerType: PhotoAttachment.ownerMaintenance,
          ownerId: rec.id,
        ),
        const SizedBox(height: 16),

        // Status
        _SectionCard(
          title: 'Service Status',
          icon: Icons.info_outlined,
          children: [
            _InfoRow(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: rec.completed ? 'Yes' : 'No',
            ),
            _InfoRow(
              icon: Icons.follow_the_signs_outlined,
              label: 'Requires Follow-up',
              value: rec.requiresFollowUp ? 'Yes' : 'No',
            ),
            if (rec.followUpNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Follow-up Notes:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rec.followUpNotes ?? '',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ],
    );
  }

  bool _hasActionsPerformed(MaintenanceRecord rec) {
    return rec.oilFilterChanged ||
        rec.fuelFilterReplaced ||
        rec.coolantFlushed ||
        rec.batteryReplaced ||
        rec.airFilterReplaced ||
        rec.beltsHosesReplaced ||
        rec.blockHeaterTested ||
        rec.racorServiced ||
        rec.atsControllerInspected ||
        rec.cdvrProgrammed ||
        rec.undervoltageRepaired ||
        rec.hazmatRemoved;
  }

  bool _hasPostServiceItems(MaintenanceRecord rec) {
    return rec.postVerifyRunsUnderLoad ||
        rec.postCheckVoltFreq ||
        rec.postInspectExhaust ||
        rec.postVerifyGrounding ||
        rec.postCheckControlPanel ||
        rec.postEnsureSafetyDevices ||
        rec.postDocumentDeficiencies ||
        rec.postLoadbankTest ||
        rec.postAtsFunctionality;
  }

  String _fmtDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final String notes;

  const _ActionChip({
    required this.label,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                notes,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String label;

  const _ChecklistItem({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}


/// Where this record stands at a glance: site, status, who and when, and how
/// complete it is.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.rec});

  final MaintenanceRecord rec;

  static String _date(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = MaintenanceProgress.compute(rec);
    final techSigned = rec.technicianSignatureName.isNotEmpty ||
        (rec.technicianSignaturePath ?? '').isNotEmpty;
    final custSigned = rec.customerSignatureName.isNotEmpty ||
        (rec.customerSignaturePath ?? '').isNotEmpty;

    // Older records were never flagged completed even when signed off, so a
    // record with its site details and both signatures counts as completed.
    final finished = rec.completed || progress.missingExpected.isEmpty;
    final (statusLabel, statusTone) = finished
        ? ('Completed', StatusTone.success)
        : ('In progress', StatusTone.warning);

    final generator = '${rec.generatorMake} ${rec.generatorModel}'.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.build_circle_outlined,
                        color: scheme.onPrimaryContainer, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.siteCode.isEmpty
                            ? (rec.address.isEmpty
                                ? 'Maintenance record'
                                : rec.address)
                            : rec.siteCode,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (rec.siteCode.isNotEmpty && rec.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            rec.address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label: statusLabel,
                  tone: statusTone,
                  icon: finished
                      ? Icons.check_circle_outline
                      : Icons.timelapse,
                ),
                if (rec.requiresFollowUp)
                  const StatusChip(
                    label: 'Follow-up needed',
                    tone: StatusTone.warning,
                    icon: Icons.flag_outlined,
                  ),
                StatusChip(
                  label: techSigned && custSigned
                      ? 'Signed by both'
                      : techSigned || custSigned
                          ? 'One signature'
                          : 'Unsigned',
                  tone: techSigned && custSigned
                      ? StatusTone.success
                      : StatusTone.neutral,
                  icon: Icons.draw_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (rec.dateOfService != null)
                  InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: _date(rec.dateOfService!),
                  ),
                if (rec.technicianName.isNotEmpty)
                  InfoChip(
                    icon: Icons.person_outline,
                    label: rec.technicianName,
                  ),
                if (generator.isNotEmpty)
                  InfoChip(icon: Icons.settings_outlined, label: generator),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: '${progress.doneCount} of ${progress.total} sections done',
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${progress.doneCount} of ${progress.total} sections done',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky actions: continue or edit the record, print it, make the PDF.
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.rec,
    required this.onEdit,
    required this.onPrint,
    required this.onExport,
  });

  final MaintenanceRecord rec;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    rec.completed || MaintenanceProgress.compute(rec)
                            .missingExpected
                            .isEmpty
                        ? 'Edit'
                        : 'Continue',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
