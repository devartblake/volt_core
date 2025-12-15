import 'package:flutter/material.dart';
import '../../presenter/widgets/utils/form_fields.dart';
import '../../infra/models/maintenance_record.dart';

/// Post-service checklist section for the maintenance form.
///
/// Binds directly to [MaintenanceRecord] booleans and notifies via [onChanged]
/// whenever any field changes.
///
/// Completion rule:
/// - Complete when all checklist items are checked.
/// - Fuel storage is informational and not required for completion.
class SectionMaintPostService extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final ValueChanged<bool>? onCompletionChanged;
  final bool readOnly;

  const SectionMaintPostService({
    super.key,
    required this.model,
    required this.onChanged,
    this.onCompletionChanged,
    this.readOnly = false,
  });

  bool _isComplete(MaintenanceRecord m) {
    return m.postVerifyRunsUnderLoad &&
        m.postCheckVoltFreq &&
        m.postInspectExhaust &&
        m.postVerifyGrounding &&
        m.postCheckControlPanel &&
        m.postEnsureSafetyDevices &&
        m.postDocumentDeficiencies &&
        m.postLoadbankTest &&
        m.postAtsFunctionality;
  }

  int _checkedCount(MaintenanceRecord m) {
    int c = 0;
    if (m.postVerifyRunsUnderLoad) c++;
    if (m.postCheckVoltFreq) c++;
    if (m.postInspectExhaust) c++;
    if (m.postVerifyGrounding) c++;
    if (m.postCheckControlPanel) c++;
    if (m.postEnsureSafetyDevices) c++;
    if (m.postDocumentDeficiencies) c++;
    if (m.postLoadbankTest) c++;
    if (m.postAtsFunctionality) c++;
    return c;
  }

  void _emit() {
    onChanged(model);
    onCompletionChanged?.call(_isComplete(model));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final complete = _isComplete(model);
    final checked = _checkedCount(model);
    const total = 9;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onCompletionChanged?.call(complete);
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Post-Service Checklist',
              subtitle:
              'Confirm the generator and associated systems were tested and left in a safe, ready state.',
              complete: complete,
              completeLabel: complete ? 'Complete' : 'Incomplete',
              trailingText: '$checked / $total',
            ),
            const SizedBox(height: 16),

            _ChecklistTile(
              label: 'Generator runs under load',
              value: model.postVerifyRunsUnderLoad,
              readOnly: readOnly,
              onChanged: (val) {
                model.postVerifyRunsUnderLoad = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Voltage & frequency checked',
              value: model.postCheckVoltFreq,
              readOnly: readOnly,
              onChanged: (val) {
                model.postCheckVoltFreq = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Exhaust system inspected',
              value: model.postInspectExhaust,
              readOnly: readOnly,
              onChanged: (val) {
                model.postInspectExhaust = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Grounding & bonding verified',
              value: model.postVerifyGrounding,
              readOnly: readOnly,
              onChanged: (val) {
                model.postVerifyGrounding = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Control panel checked',
              value: model.postCheckControlPanel,
              readOnly: readOnly,
              onChanged: (val) {
                model.postCheckControlPanel = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Safety devices functional',
              value: model.postEnsureSafetyDevices,
              readOnly: readOnly,
              onChanged: (val) {
                model.postEnsureSafetyDevices = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Deficiencies documented',
              value: model.postDocumentDeficiencies,
              readOnly: readOnly,
              onChanged: (val) {
                model.postDocumentDeficiencies = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'Load-bank test performed (if applicable)',
              value: model.postLoadbankTest,
              readOnly: readOnly,
              onChanged: (val) {
                model.postLoadbankTest = val;
                _emit();
              },
            ),
            _ChecklistTile(
              label: 'ATS functionality verified',
              value: model.postAtsFunctionality,
              readOnly: readOnly,
              onChanged: (val) {
                model.postAtsFunctionality = val;
                _emit();
              },
            ),

            const SizedBox(height: 16),
            FormDivider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            Text(
              'Fuel Storage',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _TonalInfoBox(
              child: Row(
                children: [
                  Switch(
                    value: model.fuelStoredLong,
                    onChanged: readOnly
                        ? null
                        : (val) {
                      model.fuelStoredLong = val;
                      _emit();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fuel has been stored for an extended period (may require treatment or replacement).',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool complete;
  final String completeLabel;
  final String? trailingText;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.completeLabel,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CompletionPill(
              complete: complete,
              label: completeLabel,
            ),
            if (trailingText != null) ...[
              const SizedBox(height: 6),
              Text(
                trailingText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompletionPill extends StatelessWidget {
  final bool complete;
  final String label;

  const _CompletionPill({
    required this.complete,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bg = complete
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final fg = complete
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final String label;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  const _ChecklistTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: readOnly ? null : (val) => onChanged(val ?? false),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium,
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _TonalInfoBox extends StatelessWidget {
  final Widget child;

  const _TonalInfoBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
