import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/photos/photo_attachment.dart';
import '../../../core/services/photos/photo_service.dart';

/// Reusable "Photos" section for inspection and maintenance forms.
///
/// Self-managed by owner: captures from camera/gallery, stores + backs up via
/// [PhotoService], and shows a thumbnail grid with view / caption / delete.
class PhotoAttachmentsSection extends StatefulWidget {
  const PhotoAttachmentsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
    this.title = 'Photos',
  });

  /// [PhotoAttachment.ownerInspection] or [PhotoAttachment.ownerMaintenance].
  final String ownerType;
  final String ownerId;
  final String title;

  @override
  State<PhotoAttachmentsSection> createState() =>
      _PhotoAttachmentsSectionState();
}

class _PhotoAttachmentsSectionState extends State<PhotoAttachmentsSection> {
  final ImagePicker _picker = ImagePicker();
  List<PhotoAttachment> _photos = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await PhotoService.instance
        .listForOwner(widget.ownerType, widget.ownerId);
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = p.extension(picked.name).replaceAll('.', '');
      await PhotoService.instance.addPhoto(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        bytes: bytes,
        extension: ext.isEmpty ? 'jpg' : ext,
      );
      await _load();
    } catch (e) {
      _snack('Could not add photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _capture(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _capture(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhoto(PhotoAttachment photo) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PhotoDetailPage(photo: photo),
      ),
    );
    if (changed == true) await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_photos.isNotEmpty)
                  Text(
                    '${_photos.length}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final photo in _photos)
                    _Thumbnail(photo: photo, onTap: () => _openPhoto(photo)),
                  _AddTile(busy: _busy, onTap: _showSourceSheet),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photo, required this.onTap});

  final PhotoAttachment photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Bytes-based render works on web (WebFileStore) and native (filesystem).
    final bytes = PhotoService.instance.loadBytesSync(photo);

    // Without a label a screen reader announces nothing for an image tile; the
    // caption is the only description the photo carries.
    final label = photo.caption.trim().isEmpty
        ? 'Photo attachment'
        : 'Photo: ${photo.caption.trim()}';

    return Semantics(
      button: true,
      image: true,
      label: bytes == null ? '$label (unavailable)' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 84,
            height: 84,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary),
      ),
    );
  }
}

/// Full-screen photo view with caption editing and delete.
class _PhotoDetailPage extends StatefulWidget {
  const _PhotoDetailPage({required this.photo});

  final PhotoAttachment photo;

  @override
  State<_PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<_PhotoDetailPage> {
  late final TextEditingController _caption =
      TextEditingController(text: widget.photo.caption);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _saveCaption() async {
    await PhotoService.instance.updateCaption(widget.photo.id, _caption.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption saved')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo'),
        content: const Text('Remove this photo from the record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PhotoService.instance.deletePhoto(widget.photo);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = PhotoService.instance.loadBytesSync(widget.photo);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: bytes != null
                  ? InteractiveViewer(child: Image.memory(bytes))
                  : const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 64),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caption,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'e.g. Corroded battery terminal',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveCaption,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
