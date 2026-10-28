import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/photos/photo_attachment.dart';
import '../../../core/services/photos/photo_service.dart';

/// Opens the photo gallery modal for one inspection / maintenance record.
///
/// Photos are scoped by [ownerId], so every record (and every new inspection,
/// which gets a fresh id) has its own gallery and never shows another record's
/// photos. Add, edit (caption / replace) and delete all happen in here.
Future<void> showPhotoGallery(
  BuildContext context, {
  required String ownerType,
  required String ownerId,
  String title = 'Photos',
  bool allowVideo = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _PhotoGallery(
        ownerType: ownerType,
        ownerId: ownerId,
        title: title,
        allowVideo: allowVideo && !kIsWeb,
      ),
    ),
  );
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({
    required this.ownerType,
    required this.ownerId,
    required this.title,
    required this.allowVideo,
  });

  final String ownerType;
  final String ownerId;
  final String title;
  final bool allowVideo;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final ImagePicker _picker = ImagePicker();
  List<PhotoAttachment> _photos = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;

  bool get _selecting => _selected.isNotEmpty;

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
      _selected.removeWhere((id) => !photos.any((ph) => ph.id == id));
      _loading = false;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _storePicked(XFile picked, {String caption = ''}) async {
    final bytes = await picked.readAsBytes();
    final ext = p.extension(picked.name).replaceAll('.', '');
    await PhotoService.instance.addPhoto(
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
      bytes: bytes,
      extension: ext.isEmpty ? 'jpg' : ext,
      caption: caption,
    );
  }

  Future<void> _add(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 70,
          maxWidth: 1600,
        );
        for (final file in picked) {
          await _storePicked(file);
        }
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (picked != null) await _storePicked(picked);
      }
      await _load();
    } catch (e) {
      _snack('Could not add photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVideo(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked != null) {
        await PhotoService.instance.addVideo(
          ownerType: widget.ownerType,
          ownerId: widget.ownerId,
          sourcePath: picked.path,
        );
      }
      await _load();
    } catch (e) {
      _snack('Could not add video: $e');
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
                _add(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _add(ImageSource.gallery);
              },
            ),
            if (widget.allowVideo) ...[
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose video from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addVideo(ImageSource.gallery);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(PhotoAttachment photo) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PhotoEditorPage(
          photo: photo,
          picker: _picker,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  void _toggle(PhotoAttachment photo) {
    setState(() {
      if (!_selected.remove(photo.id)) _selected.add(photo.id);
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final ok = await _confirmDelete(
      context,
      count == 1 ? 'Delete this photo?' : 'Delete $count photos?',
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      for (final photo in _photos.where((ph) => _selected.contains(ph.id))) {
        await PhotoService.instance.deletePhoto(photo);
      }
      _selected.clear();
      await _load();
    } catch (e) {
      _snack('Could not delete photos: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selecting
                      ? '${_selected.length} selected'
                      : '${widget.title} (${_photos.length})',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (_selecting) ...[
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(
                    () => _selected.addAll(_photos.map((ph) => ph.id)),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  onPressed: _busy ? null : _deleteSelected,
                ),
                IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                ),
              ] else ...[
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _showSourceSheet,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add'),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _photos.isEmpty
                  ? _EmptyState(onAdd: _showSourceSheet)
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (context, i) {
                        final photo = _photos[i];
                        return _GridTile(
                          photo: photo,
                          selected: _selected.contains(photo.id),
                          selecting: _selecting,
                          onTap: () =>
                              _selecting ? _toggle(photo) : _open(photo),
                          onLongPress: () => _toggle(photo),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No photos yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Photos you add here belong to this record only.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add photo'),
          ),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.photo,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final PhotoAttachment photo;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes =
        photo.isVideo ? null : PhotoService.instance.loadBytesSync(photo);
    final caption = photo.caption.trim();

    return Semantics(
      button: true,
      image: true,
      selected: selected,
      label: caption.isEmpty
          ? (photo.isVideo ? 'Video attachment' : 'Photo attachment')
          : '${photo.isVideo ? 'Video' : 'Photo'}: $caption',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo.isVideo)
                Container(
                  color: Colors.black87,
                  child: const Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 44),
                )
              else if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
              else
                Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              if (caption.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              if (selecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: selected
                        ? theme.colorScheme.primary
                        : Colors.black45,
                    child: Icon(
                      selected ? Icons.check : null,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: theme.colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, String title) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('This removes the photo from the record.'),
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
}

/// Full-screen view of one photo: edit the caption, replace the image, delete.
/// Pops `true` when anything changed so the gallery reloads.
class _PhotoEditorPage extends StatefulWidget {
  const _PhotoEditorPage({required this.photo, required this.picker});

  final PhotoAttachment photo;
  final ImagePicker picker;

  @override
  State<_PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<_PhotoEditorPage> {
  late final TextEditingController _caption =
      TextEditingController(text: widget.photo.caption);
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _saveCaption() async {
    await PhotoService.instance.updateCaption(widget.photo.id, _caption.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _replace(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await widget.picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = p.extension(picked.name).replaceAll('.', '');
      // Add the new image first so a failure never leaves the record without
      // either photo, then retire the old one.
      await PhotoService.instance.addPhoto(
        ownerType: widget.photo.ownerType,
        ownerId: widget.photo.ownerId,
        bytes: bytes,
        extension: ext.isEmpty ? 'jpg' : ext,
        caption: _caption.text,
      );
      await PhotoService.instance.deletePhoto(widget.photo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not replace photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showReplaceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Retake with camera'),
              onTap: () {
                Navigator.pop(ctx);
                _replace(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose another from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _replace(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await _confirmDelete(context, 'Delete this photo?');
    if (ok != true) return;
    await PhotoService.instance.deletePhoto(widget.photo);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.photo.isVideo;
    final bytes =
        isVideo ? null : PhotoService.instance.loadBytesSync(widget.photo);
    return Scaffold(
      appBar: AppBar(
        title: Text(isVideo ? 'Edit video' : 'Edit photo'),
        actions: [
          if (!isVideo)
            IconButton(
            icon: const Icon(Icons.published_with_changes_outlined),
            tooltip: 'Replace photo',
            onPressed: _busy ? null : _showReplaceSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: isVideo
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: () => OpenFilex.open(widget.photo.localPath),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play video'),
                      ),
                    )
                  : bytes != null
                  ? InteractiveViewer(child: Image.memory(bytes))
                  : const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 64),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveCaption(),
                      decoration: const InputDecoration(
                        labelText: 'Caption',
                        hintText: 'e.g. Corroded battery terminal',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _saveCaption,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
