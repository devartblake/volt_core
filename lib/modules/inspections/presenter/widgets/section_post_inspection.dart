import 'package:flutter/material.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/inspection_checklist.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class SectionPostInspection extends StatefulWidget {
  final InspectionEntity model;
  final ValueChanged<InspectionEntity> onChanged;

  const SectionPostInspection({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<SectionPostInspection> createState() => _SectionPostInspectionState();
}

class _SectionPostInspectionState extends State<SectionPostInspection> {
  /// The parent's current entity, never a snapshot.
  ///
  /// This used to be a field seeded in initState and never resynced. Because
  /// every section held its own copy from first build, each section's
  /// `copyWith` was applied to the *original* entity — so whichever section
  /// the technician edited last silently discarded every other section's data
  /// and the inspection saved almost empty.
  InspectionEntity get m => widget.model;

  void _update(InspectionEntity Function(InspectionEntity) transform) {
    widget.onChanged(transform(widget.model));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Both the count and the rows below walk the same list, so an item can no
    // longer be added to one and forgotten in the other.
    final total = kInspectionChecklist.length;
    final completed = m.checklistCompletedCount;
    final percentage = (completed / total * 100).toInt();
    final noted = kInspectionChecklist
        .where((item) => m.checklistNoteFor(item.key).isNotEmpty)
        .length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.checklist_rtl,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post-Inspection Checklist',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completed of $total answered yes'
                        '${noted > 0 ? '  ·  $noted with conclusions' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage < 50
                      ? theme.colorScheme.error
                      : percentage < 80
                      ? theme.status.warning
                      : theme.status.success,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage% Complete',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            for (final item in kInspectionChecklist) ...[
              StatusSwitchTile(
                label: item.label,
                icon: _iconFor(item.key),
                value: item.read(m),
                onChanged: (v) => _update((curr) => item.write(curr, v)),
                note: m.checklistNoteFor(item.key),
                onNotePressed: () => _editConclusion(item),
                margin: const EdgeInsets.only(bottom: 8),
              ),
              // Show the conclusion under its own row rather than only behind
              // the dialog. A finding nobody can see without tapping into it is
              // a finding that gets missed on review.
              if (m.checklistNoteFor(item.key).isNotEmpty)
                _ConclusionSummary(
                  text: m.checklistNoteFor(item.key),
                  onTap: () => _editConclusion(item),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editConclusion(InspectionChecklistItem item) async {
    final result = await ChecklistNoteDialog.show(
      context,
      itemLabel: item.label,
      answer: item.read(widget.model),
      initialText: widget.model.checklistNoteFor(item.key),
    );
    // null is a dismissal; "" is a deliberate clear, which withChecklistNote
    // turns into a removal.
    if (result == null) return;
    _update((curr) => curr.withChecklistNote(item.key, result));
  }

  /// Icons stay in the presenter — the checklist itself is domain data and has
  /// no business importing material.
  static IconData _iconFor(String key) {
    switch (key) {
      case 'genset_runs_under_load':
        return Icons.power;
      case 'voltage_frequency_ok':
        return Icons.electrical_services;
      case 'exhaust_ok':
        return Icons.air;
      case 'grounding_bonding_ok':
        return Icons.bolt;
      case 'control_panel_ok':
        return Icons.dashboard;
      case 'safety_devices_ok':
        return Icons.security;
      case 'deficiencies_documented':
        return Icons.description;
      case 'loadbank_done':
        return Icons.science;
      case 'ats_verified':
        return Icons.swap_horiz;
      case 'fuel_stored_over_1yr':
        return Icons.water_drop;
      default:
        return Icons.check_circle_outline;
    }
  }
}

/// One saved conclusion, rendered under the item it belongs to.
class _ConclusionSummary extends StatelessWidget {
  const _ConclusionSummary({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
