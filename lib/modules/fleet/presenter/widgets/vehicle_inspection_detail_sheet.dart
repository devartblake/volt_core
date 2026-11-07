import 'dart:io';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/signature_surface.dart';
import '../../../../shared/widgets/thumbnail_image.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/services/photos/photo_service.dart';
import '../../../../core/services/storage/path_resolver.dart';
import '../../../../core/services/storage/web_file_store.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../../domain/entities/vehicle_maintenance_check.dart'
    show CheckStatus, CheckStatusX;

/// Opens one inspection from the history: who did it, the four photos, every
/// answer, and both signatures.
Future<void> showVehicleInspectionDetail(
  BuildContext context,
  VehicleInspection inspection,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _InspectionDetail(inspection: inspection),
    ),
  );
}

class _InspectionDetail extends StatefulWidget {
  const _InspectionDetail({required this.inspection});

  final VehicleInspection inspection;

  @override
  State<_InspectionDetail> createState() => _InspectionDetailState();
}

class _InspectionDetailState extends State<_InspectionDetail> {
  Map<String, PhotoAttachment> _slots = const {};
  List<PhotoAttachment> _extras = const [];
  Uint8List? _driverSignature;
  Uint8List? _dispatcherSignature;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = widget.inspection;
    var photos = const <PhotoAttachment>[];
    try {
      photos = await PhotoService.instance
          .listForOwner(PhotoAttachment.ownerVehicleInspection, i.id);
    } catch (_) {
      // Show the rest of the record even if photos cannot be read.
    }
    final driver = await _readBytes(i.driverSignaturePath);
    final dispatcher = await _readBytes(i.dispatcherSignaturePath);

    if (!mounted) return;
    setState(() {
      _slots = {
        for (final ph in photos)
          if (ph.slot.isNotEmpty) ph.slot: ph,
      };
      _extras = photos.where((ph) => ph.slot.isEmpty).toList();
      _driverSignature = driver;
      _dispatcherSignature = dispatcher;
      _loading = false;
    });
  }

  static Future<Uint8List?> _readBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    final fromStore = WebFileStore.instance.getSync(path);
    if (fromStore != null) return fromStore;
    if (kIsWeb) return null;
    try {
      final file = await PathResolver.resolveFile(path);
      return await file?.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  static String _stamp(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}  $hh:$mm';
  }

  void _openPhoto(PhotoAttachment photo, String title) {
    final bytes = PhotoService.instance.loadBytesSync(photo);
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: InteractiveViewer(child: Image.memory(bytes))),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(tooltip: 'Close', 
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(title, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = widget.inspection;
    final items = inspectionItemsFor(i.cadence);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${i.cadence.label} inspection',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Text(_stamp(i.inspectedAt), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (i.odometer > 0) _chip(theme, Icons.speed_outlined, '${i.odometer} mi'),
            _chip(
              theme,
              i.hasIssues ? Icons.warning_amber_outlined : Icons.check_circle_outline,
              i.hasIssues ? '${i.issueCount} flagged' : 'No issues',
              color: i.hasIssues ? theme.colorScheme.error : null,
            ),
            if (i.isSigned)
              _chip(theme, Icons.verified_outlined, 'Signed by both'),
          ],
        ),
        const SizedBox(height: 16),

        _heading(theme, 'Photos'),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 4 / 3,
            children: [
              for (final slot in InspectionPhotoSlot.values)
                _slotTile(theme, slot),
            ],
          ),
        if (_extras.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_extras.length} extra photo${_extras.length == 1 ? '' : 's'} or video${_extras.length == 1 ? '' : 's'} attached',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 18),

        _heading(theme, 'Answers'),
        const SizedBox(height: 6),
        for (final item in items) _answerRow(theme, i, item),
        if (i.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _heading(theme, 'Notes'),
          const SizedBox(height: 4),
          Text(i.notes.trim()),
        ],
        const SizedBox(height: 18),

        _heading(theme, 'Signatures'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _signatureBox(
                theme,
                'Assigned person',
                i.driverName,
                _driverSignature,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _signatureBox(
                theme,
                'Dispatcher',
                i.dispatcherName,
                _dispatcherSignature,
              ),
            ),
          ],
        ),
        if (i.signedAt != null) ...[
          const SizedBox(height: 6),
          Text('Signed ${_stamp(i.signedAt!)}', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _heading(ThemeData theme, String text) => Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: theme.colorScheme.primary,
        ),
      );

  Widget _chip(ThemeData theme, IconData icon, String text, {Color? color}) =>
      Chip(
        avatar: Icon(icon, size: 16, color: color ?? theme.colorScheme.onSurface),
        // Explicit colour: the theme's chip text was nearly invisible here.
        label: Text(
          text,
          style: TextStyle(color: color ?? theme.colorScheme.onSurface),
        ),
        visualDensity: VisualDensity.compact,
      );

  Widget _slotTile(ThemeData theme, InspectionPhotoSlot slot) {
    final photo = _slots[slot.key];
    final bytes = photo == null ? null : PhotoService.instance.loadBytesSync(photo);

    return InkWell(
      onTap: photo == null ? null : () => _openPhoto(photo, slot.label),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: bytes != null
                  ? ThumbnailImage.memory(bytes)
                  : Center(
                      child: Text(
                        'No photo',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  slot.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerRow(ThemeData theme, VehicleInspection i, InspectionItem item) {
    final status = i.results[item.key];
    final color = switch (status) {
      CheckStatus.ok => theme.status.success,
      CheckStatus.attention => theme.status.warning,
      CheckStatus.fail => theme.colorScheme.error,
      null => theme.colorScheme.outline,
    };
    final note = i.itemNotes[item.key] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.label)),
              Text(
                status?.label ?? 'Not answered',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(note, style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ),
        ],
      ),
    );
  }

  Widget _signatureBox(
    ThemeData theme,
    String role,
    String name,
    Uint8List? image,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        SignatureImagePreview(bytes: image),
        const SizedBox(height: 4),
        Text(name.isEmpty ? '-' : name, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
