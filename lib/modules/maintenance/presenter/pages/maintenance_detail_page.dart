import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_drawer.dart';
import '../../data/models/maintenance_record.dart';
import '../../providers/maintenance_providers.dart';

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
      return Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance Detail'),
          leading: Navigator.of(context).canPop()
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          )
              : null,
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(rec.siteCode.isEmpty ? 'Maintenance Detail' : rec.siteCode),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              await repo.exportMaintenancePdf(rec);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Text('PDF export started'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              context.push('/maintenance/new?id=$id');
            },
          ),
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
                        'This action cannot be undone. All infra for this maintenance record will be permanently deleted.',
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
                    if (context.mounted) {
                      context.go('/maintenance');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _DetailBody(rec: rec),
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
        // Header Card with Key Info
        Card(
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.build_circle_outlined,
                        color: colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.siteCode.isEmpty ? 'Maintenance Record' : rec.siteCode,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (rec.address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    rec.address,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (rec.dateOfService != null) ...[
                  const SizedBox(height: 16),
                  Divider(color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Service Date',
                    value: _fmtDate(rec.dateOfService!),
                  ),
                ],
              ],
            ),
          ),
        ),

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
                _ActionChip(label: 'Oil filter changed', notes: rec.oilFilterNotes),
              if (rec.fuelFilterReplaced)
                _ActionChip(label: 'Fuel filter replaced', notes: rec.fuelFilterNotes),
              if (rec.coolantFlushed)
                _ActionChip(label: 'Coolant flushed', notes: rec.coolantNotes),
              if (rec.batteryReplaced)
                _ActionChip(label: 'Battery replaced', notes: rec.batteryNotes),
              if (rec.airFilterReplaced)
                _ActionChip(label: 'Air filter replaced', notes: rec.airFilterNotes),
              if (rec.beltsHosesReplaced)
                _ActionChip(label: 'Belts/hoses replaced', notes: rec.beltsHosesNotes),
              if (rec.blockHeaterTested)
                _ActionChip(label: 'Block heater tested', notes: rec.blockHeaterNotes),
              if (rec.racorServiced)
                _ActionChip(label: 'Racor serviced', notes: rec.racorNotes),
              if (rec.atsControllerInspected)
                _ActionChip(label: 'ATS/controller inspected', notes: rec.atsControllerNotes),
              if (rec.cdvrProgrammed)
                _ActionChip(label: 'CDVR programmed', notes: rec.cdvrNotes),
              if (rec.undervoltageRepaired)
                _ActionChip(label: 'Under-voltage repaired', notes: rec.undervoltageNotes),
              if (rec.hazmatRemoved)
                _ActionChip(label: 'Hazmat removed', notes: rec.hazmatNotes),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Service Observations
        if (rec.serviceObservations?.isNotEmpty ?? false) ...[
          _SectionCard(
            title: 'Service Observations',
            icon: Icons.notes_outlined,
            children: [
              Text(
                rec.serviceObservations!,
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
                const _ChecklistItem(label: 'Generator runs under load'),
              if (rec.postCheckVoltFreq)
                const _ChecklistItem(label: 'Voltage & frequency checked'),
              if (rec.postInspectExhaust)
                const _ChecklistItem(label: 'Exhaust system inspected'),
              if (rec.postVerifyGrounding)
                const _ChecklistItem(label: 'Grounding & bonding verified'),
              if (rec.postCheckControlPanel)
                const _ChecklistItem(label: 'Control panel checked'),
              if (rec.postEnsureSafetyDevices)
                const _ChecklistItem(label: 'Safety devices functional'),
              if (rec.postDocumentDeficiencies)
                const _ChecklistItem(label: 'Deficiencies documented'),
              if (rec.postLoadbankTest)
                const _ChecklistItem(label: 'Load-bank test performed'),
              if (rec.postAtsFunctionality)
                const _ChecklistItem(label: 'ATS functionality verified'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Signatures
        if (rec.technicianSignatureName.isNotEmpty || rec.customerSignatureName.isNotEmpty) ...[
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
                    padding: const EdgeInsets.only(left: 32, top: 4),
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
                    padding: const EdgeInsets.only(left: 32, top: 4),
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
                rec.followUpNotes!,
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
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
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