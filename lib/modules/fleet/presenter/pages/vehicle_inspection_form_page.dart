import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/nav_extensions.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../../domain/entities/vehicle_maintenance_check.dart'
    show CheckStatus, CheckStatusX;
import '../../infra/repositories/vehicle_inspection_repository.dart';
import '../fleet_providers.dart';

/// Weekly / monthly vehicle walk-around.
///
/// Every item defaults to OK so a clean vehicle is a quick pass; anything that
/// is not OK asks for a note. Photos and videos attach to the inspection itself
/// (owner type `vehicle_inspection`) so damage is documented where it was found.
class VehicleInspectionFormPage extends ConsumerStatefulWidget {
  const VehicleInspectionFormPage({
    super.key,
    required this.vehicleId,
    required this.cadence,
  });

  final String vehicleId;
  final InspectionCadence cadence;

  @override
  ConsumerState<VehicleInspectionFormPage> createState() =>
      _VehicleInspectionFormPageState();
}

class _VehicleInspectionFormPageState
    extends ConsumerState<VehicleInspectionFormPage> {
  VehicleInspection? _draft;
  late final TextEditingController _odometer = TextEditingController();
  late final TextEditingController _notes = TextEditingController();
  final Map<String, TextEditingController> _itemNotes = {};
  bool _saving = false;
  bool _dirty = false;
  bool _saved = false;

  @override
  void dispose() {
    _odometer.dispose();
    _notes.dispose();
    for (final c in _itemNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureDraft(VehicleEntity vehicle) {
    if (_draft != null) return;
    final auth = ref.read(authStateProvider);
    _draft = VehicleInspection.newDraft(
      vehicleId: vehicle.id,
      cadence: widget.cadence,
      odometer: vehicle.odometer,
      inspectorUserId: auth.userId,
      inspectorName: auth.displayName ?? auth.email ?? '',
    );
    _odometer.text = vehicle.odometer == 0 ? '' : '${vehicle.odometer}';
  }

  TextEditingController _noteController(String key) =>
      _itemNotes.putIfAbsent(key, () => TextEditingController());

  void _setStatus(String key, CheckStatus status) {
    final draft = _draft!;
    setState(() {
      _dirty = true;
      _draft = draft.copyWith(results: {...draft.results, key: status});
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;

    // A flagged item with no explanation is the kind of record nobody can act
    // on, so ask for the note rather than saving it.
    final missing = <String>[];
    for (final item in inspectionItemsFor(widget.cadence)) {
      final status = draft.results[item.key] ?? CheckStatus.ok;
      if (status.needsFollowUp && _noteController(item.key).text.trim().isEmpty) {
        missing.add(item.label);
      }
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add a note for: ${missing.take(3).join(', ')}'
              '${missing.length > 3 ? '…' : ''}'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notes = <String, String>{
        for (final entry in _itemNotes.entries)
          if (entry.value.text.trim().isNotEmpty &&
              (draft.results[entry.key] ?? CheckStatus.ok).needsFollowUp)
            entry.key: entry.value.text.trim(),
      };
      final saved = draft.copyWith(
        odometer: int.tryParse(_odometer.text.trim()) ?? draft.odometer,
        itemNotes: notes,
        notes: _notes.text.trim(),
      );
      await ref.read(vehicleInspectionRepositoryProvider).save(saved);
      ref.invalidate(vehicleInspectionsProvider(widget.vehicleId));

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved.hasIssues
              ? '${widget.cadence.label} inspection saved – '
                  '${saved.issueCount} item(s) flagged'
              : '${widget.cadence.label} inspection saved'),
        ),
      );
      context.popOrGo(
        RoutePaths.fleetDetail.replaceFirst(':id', widget.vehicleId),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save inspection: $e')),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this inspection?'),
        content: const Text('Nothing has been saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    final title = '${widget.cadence.label} inspection';

    return PopScope(
      canPop: !_dirty || _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) context.popIfPossible();
      },
      child: AppPage(
        title: title,
        actions: [
          IconButton(
            tooltip: 'Save inspection',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
          ),
        ],
        body: vehicle.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState.error(message: '$e'),
          data: (found) {
            if (found == null) {
              return const EmptyState(
                icon: Icons.no_transfer_outlined,
                title: 'Vehicle not found',
                message: 'It may have been removed.',
              );
            }
            _ensureDraft(found);
            return _buildForm(context, found);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, VehicleEntity vehicle) {
    final theme = Theme.of(context);
    final draft = _draft!;
    final items = inspectionItemsFor(widget.cadence);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(vehicle.displayTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          widget.cadence == InspectionCadence.monthly
              ? 'Monthly: the weekly walk-around plus the extended checks.'
              : 'Weekly walk-around.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _odometer,
          keyboardType: TextInputType.number,
          onChanged: (_) => _dirty = true,
          decoration: const InputDecoration(
            labelText: 'Odometer (mi)',
            prefixIcon: Icon(Icons.speed_outlined),
          ),
        ),
        const SizedBox(height: 16),
        for (final item in items) _buildItem(theme, item, draft),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 10,
          onChanged: (_) => _dirty = true,
          decoration: const InputDecoration(
            labelText: 'General notes',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        PhotoAttachmentsSection(
          ownerType: PhotoAttachment.ownerVehicleInspection,
          ownerId: draft.id,
          title: 'Photos & videos',
          allowVideo: true,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          label: Text('Save ${widget.cadence.label.toLowerCase()} inspection'),
        ),
      ],
    );
  }

  Widget _buildItem(ThemeData theme, InspectionItem item, VehicleInspection draft) {
    final status = draft.results[item.key] ?? CheckStatus.ok;
    final flagged = status.needsFollowUp;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<CheckStatus>(
              showSelectedIcon: false,
              segments: [
                for (final s in CheckStatus.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {status},
              onSelectionChanged: (set) => _setStatus(item.key, set.first),
            ),
            if (flagged) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteController(item.key),
                onChanged: (_) => _dirty = true,
                decoration: InputDecoration(
                  labelText: 'What is wrong?',
                  isDense: true,
                  errorText: null,
                  prefixIcon: Icon(
                    Icons.warning_amber_outlined,
                    color: status == CheckStatus.fail
                        ? theme.colorScheme.error
                        : null,
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
