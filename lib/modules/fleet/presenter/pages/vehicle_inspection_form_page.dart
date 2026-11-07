import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../../../../shared/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:signature/signature.dart';

import '../../../../app/nav_extensions.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/services/photos/photo_service.dart';
import '../../../../core/services/storage/file_storage_service.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../../domain/entities/vehicle_maintenance_check.dart'
    show CheckStatus, CheckStatusX;
import '../../infra/repositories/vehicle_inspection_repository.dart';
import '../fleet_providers.dart';

/// Daily, weekly or monthly vehicle walk-around.
///
/// It can only be completed when **everything** is in:
/// every question answered on purpose, a separate photo of the front, back,
/// driver side and passenger side, and a signature from both the assigned
/// person and the dispatcher. Pressing save with anything missing opens a
/// dialog naming exactly what is missing, and nothing is saved until it is
/// fixed.
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
  final ImagePicker _picker = ImagePicker();

  VehicleInspection? _draft;
  final Map<InspectionPhotoSlot, PhotoAttachment> _slotPhotos = {};

  final _odometer = TextEditingController();
  final _notes = TextEditingController();
  final _driverName = TextEditingController();
  final _dispatcherName = TextEditingController();
  final Map<String, TextEditingController> _itemNotes = {};

  late final SignatureController _driverSignature = _newPad();
  late final SignatureController _dispatcherSignature = _newPad();

  final _checklistKey = GlobalKey();
  final _photosKey = GlobalKey();
  final _signaturesKey = GlobalKey();

  bool _saving = false;
  bool _dirty = false;
  bool _saved = false;

  SignatureController _newPad() => SignatureController(
        penStrokeWidth: 2.5,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
        onDrawEnd: () => setState(() => _dirty = true),
      );

  /// Real cameras exist on phones and tablets; desktop and web fall back to
  /// choosing a file so the form can still be tested there.
  bool get _hasCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _odometer.dispose();
    _notes.dispose();
    _driverName.dispose();
    _dispatcherName.dispose();
    for (final c in _itemNotes.values) {
      c.dispose();
    }
    _driverSignature.dispose();
    _dispatcherSignature.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ setup

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

    // A dispatcher or manager signing in is most likely the dispatcher signing.
    final role = auth.currentRole;
    if (role != null && role != UserRole.tech) {
      _dispatcherName.text = auth.displayName ?? '';
    }
    _prefillDriver(vehicle);
  }

  /// The assigned person's name, from the team list. Best effort: it can be
  /// typed if the list is unavailable.
  Future<void> _prefillDriver(VehicleEntity vehicle) async {
    final id = vehicle.assignedToUserId;
    if (id == null || id.isEmpty) return;
    try {
      final members = await ref.read(fleetAssignableMembersProvider.future);
      for (final m in members) {
        if (m.userId == id && _driverName.text.trim().isEmpty && mounted) {
          setState(() => _driverName.text = m.displayName);
        }
      }
    } catch (_) {
      // Leave it blank to be typed.
    }
  }

  TextEditingController _noteController(String key) =>
      _itemNotes.putIfAbsent(key, () => TextEditingController());

  // ----------------------------------------------------------------- answers

  void _setStatus(String key, CheckStatus? status) {
    final draft = _draft!;
    final next = {...draft.results};
    if (status == null) {
      next.remove(key);
    } else {
      next[key] = status;
    }
    setState(() {
      _dirty = true;
      _draft = draft.copyWith(results: next);
    });
  }

  // ------------------------------------------------------------------ photos

  Future<void> _captureSlot(InspectionPhotoSlot slot) async {
    final draft = _draft;
    if (draft == null) return;
    try {
      final picked = await _picker.pickImage(
        source: _hasCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = p.extension(picked.name).replaceAll('.', '');
      final photo = await PhotoService.instance.addPhoto(
        ownerType: PhotoAttachment.ownerVehicleInspection,
        ownerId: draft.id,
        bytes: bytes,
        extension: ext.isEmpty ? 'jpg' : ext,
        slot: slot.key,
      );

      // One photo per view: a retake replaces the earlier one.
      final old = _slotPhotos[slot];
      if (old != null) await PhotoService.instance.deletePhoto(old);

      if (!mounted) return;
      setState(() {
        _slotPhotos[slot] = photo;
        _dirty = true;
      });
    } catch (e) {
      _snack('Could not take the photo: $e');
    }
  }

  /// Removes everything captured for a draft that is being thrown away.
  Future<void> _discardCaptured() async {
    final draft = _draft;
    if (draft == null) return;
    try {
      final photos = await PhotoService.instance.listForOwner(
        PhotoAttachment.ownerVehicleInspection,
        draft.id,
      );
      for (final photo in photos) {
        await PhotoService.instance.deletePhoto(photo);
      }
    } catch (_) {
      // Leftover files are harmless.
    }
  }

  // -------------------------------------------------------------------- save

  List<String> _gaps() {
    final draft = _draft!;
    return inspectionGaps(
      cadence: widget.cadence,
      results: draft.results,
      itemNotes: {
        for (final e in _itemNotes.entries) e.key: e.value.text,
      },
      photoSlots: _slotPhotos.keys.toSet(),
      driverName: _driverName.text,
      dispatcherName: _dispatcherName.text,
      hasDriverSignature: _driverSignature.isNotEmpty,
      hasDispatcherSignature: _dispatcherSignature.isNotEmpty,
      hasOdometer: int.tryParse(_odometer.text.trim()) != null,
    );
  }

  Future<void> _showGaps(List<String> gaps) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
          title: const Text('Inspection not complete'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These are still missing. The inspection cannot be '
                    'completed until each one is done.',
                  ),
                  const SizedBox(height: 12),
                  for (final gap in gaps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.radio_button_unchecked,
                              size: 16, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(gap)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Go back and fix'),
            ),
          ],
        );
      },
    );

    // Bring the first problem into view.
    final first = gaps.first;
    final key = first.startsWith('Photo:')
        ? _photosKey
        : (first.startsWith('Answer') ||
                first.startsWith('Explain') ||
                first.startsWith('...'))
            ? _checklistKey
            : (first.contains('signature') || first.contains('name'))
                ? _signaturesKey
                : null;
    if (!mounted) return;
    final ctx = key?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.05,
      );
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;

    final gaps = _gaps();
    if (gaps.isNotEmpty) {
      await _showGaps(gaps);
      return;
    }

    setState(() => _saving = true);
    try {
      final driverPng = await _driverSignature.toPngBytes();
      final dispatcherPng = await _dispatcherSignature.toPngBytes();
      if (driverPng == null || dispatcherPng == null) {
        throw StateError('A signature could not be captured.');
      }

      final storage = FileStorageService.instance;
      final driverPath = await storage.saveInspectionSignature(
        inspectionId: draft.id,
        signatureBytes: driverPng,
        fileName: 'vehicle_${draft.id}_driver.png',
      );
      final dispatcherPath = await storage.saveInspectionSignature(
        inspectionId: draft.id,
        signatureBytes: dispatcherPng,
        fileName: 'vehicle_${draft.id}_dispatcher.png',
      );

      final notes = <String, String>{
        for (final e in _itemNotes.entries)
          if (e.value.text.trim().isNotEmpty &&
              (draft.results[e.key] ?? CheckStatus.ok).needsFollowUp)
            e.key: e.value.text.trim(),
      };

      final saved = draft.copyWith(
        inspectedAt: DateTime.now(),
        odometer: int.tryParse(_odometer.text.trim()) ?? draft.odometer,
        itemNotes: notes,
        notes: _notes.text.trim(),
        driverName: _driverName.text.trim(),
        driverSignaturePath: driverPath,
        dispatcherName: _dispatcherName.text.trim(),
        dispatcherSignaturePath: dispatcherPath,
        signedAt: DateTime.now(),
      );
      await ref.read(vehicleInspectionRepositoryProvider).save(saved);
      ref.invalidate(vehicleInspectionsProvider(widget.vehicleId));
      ref.invalidate(allVehicleInspectionsProvider);

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      _snack(saved.hasIssues
          ? '${widget.cadence.label} inspection saved - '
              '${saved.issueCount} item(s) flagged'
          : '${widget.cadence.label} inspection saved');
      context.popOrGo(
        RoutePaths.fleetDetail.replaceFirst(':id', widget.vehicleId),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save inspection: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    AppSnackBar.info(context, message);
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this inspection?'),
        content: const Text(
          'Nothing has been saved yet. The photos you took will be removed.',
        ),
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
    if (leave == true) await _discardCaptured();
    return leave ?? false;
  }

  // ------------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));

    return PopScope(
      canPop: !_dirty || _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) context.popIfPossible();
      },
      child: AppPage(
        title: '${widget.cadence.label} inspection',
        actions: [
          IconButton(
            tooltip: 'Complete inspection',
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
    final answered = items.where((i) => draft.results.containsKey(i.key)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(vehicle.displayTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          switch (widget.cadence) {
            InspectionCadence.daily =>
              'Daily check before the vehicle is taken out. Everything below '
                  'must be completed.',
            InspectionCadence.weekly => 'Weekly walk-around.',
            InspectionCadence.monthly =>
              'Monthly: the weekly walk-around plus the extended checks.',
          },
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _odometer,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _dirty = true),
          decoration: const InputDecoration(
            labelText: 'Odometer (mi) *',
            prefixIcon: Icon(Icons.speed_outlined),
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle(theme, 'Photos of the vehicle', Icons.photo_camera_outlined,
            key: _photosKey,
            trailing: '${_slotPhotos.length} of ${InspectionPhotoSlot.values.length}'),
        const SizedBox(height: 4),
        Text(
          'A separate photo of each side is required.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _buildPhotoGrid(theme),
        const SizedBox(height: 20),

        _sectionTitle(theme, 'Checklist', Icons.checklist_outlined,
            key: _checklistKey, trailing: '$answered of ${items.length} answered'),
        const SizedBox(height: 8),
        for (final item in items) _buildItem(theme, item, draft),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 10,
          onChanged: (_) => setState(() => _dirty = true),
          decoration: const InputDecoration(
            labelText: 'General notes',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        PhotoAttachmentsSection(
          ownerType: PhotoAttachment.ownerVehicleInspection,
          ownerId: draft.id,
          title: 'Extra photos & videos',
          allowVideo: true,
          hideSlotted: true,
        ),
        const SizedBox(height: 20),

        _sectionTitle(theme, 'Signatures', Icons.draw_outlined,
            key: _signaturesKey),
        const SizedBox(height: 8),
        _buildSignatureCard(
          theme,
          title: 'Assigned person',
          hint: 'Takes responsibility for the vehicle',
          nameController: _driverName,
          pad: _driverSignature,
        ),
        const SizedBox(height: 12),
        _buildSignatureCard(
          theme,
          title: 'Dispatcher',
          hint: 'Signs off the inspection',
          nameController: _dispatcherName,
          pad: _dispatcherSignature,
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          label: Text('Complete ${widget.cadence.label.toLowerCase()} inspection'),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    ThemeData theme,
    String text,
    IconData icon, {
    required GlobalKey key,
    String? trailing,
  }) {
    return Row(
      key: key,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(trailing, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPhotoGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 4 / 3,
          children: [
            for (final slot in InspectionPhotoSlot.values)
              _PhotoSlotTile(
                label: slot.label,
                photo: _slotPhotos[slot],
                onTap: () => _captureSlot(slot),
              ),
          ],
        );
      },
    );
  }

  Widget _buildItem(ThemeData theme, InspectionItem item, VehicleInspection draft) {
    final status = draft.results[item.key];
    final flagged = status?.needsFollowUp ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.label, style: theme.textTheme.bodyMedium),
                ),
                if (status == null)
                  Text(
                    'Not answered',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<CheckStatus>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: [
                for (final s in CheckStatus.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: status == null ? const {} : {status},
              onSelectionChanged: (set) =>
                  _setStatus(item.key, set.isEmpty ? null : set.first),
            ),
            if (flagged) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteController(item.key),
                onChanged: (_) => setState(() => _dirty = true),
                decoration: InputDecoration(
                  labelText: 'What is wrong? *',
                  isDense: true,
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

  Widget _buildSignatureCard(
    ThemeData theme, {
    required String title,
    required String hint,
    required TextEditingController nameController,
    required SignatureController pad,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(hint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: const InputDecoration(
                labelText: 'Full name *',
                isDense: true,
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: pad,
                  height: 140,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(pad.clear),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One required view of the vehicle: a labelled box that shows the photo once
/// taken and lets it be retaken.
class _PhotoSlotTile extends StatelessWidget {
  const _PhotoSlotTile({
    required this.label,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final PhotoAttachment? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = photo == null ? null : PhotoService.instance.loadBytesSync(photo!);
    final done = photo != null;

    return Semantics(
      button: true,
      label: done ? '$label photo taken, tap to retake' : '$label photo required',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? theme.colorScheme.primary : theme.colorScheme.error,
              width: done ? 1.5 : 2,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  ThumbnailImage.memory(bytes)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 34, color: theme.colorScheme.error),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to take photo',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          done ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: done ? Colors.lightGreenAccent : Colors.amber,
                        ),
                      ],
                    ),
                  ),
                ),
                if (done)
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.refresh, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
