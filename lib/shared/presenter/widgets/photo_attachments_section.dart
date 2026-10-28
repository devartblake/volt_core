import 'package:flutter/material.dart';

import '../../../core/services/photos/photo_attachment.dart';
import '../../../core/services/photos/photo_service.dart';
import 'photo_gallery_sheet.dart';

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
    this.allowVideo = false,
  });

  /// [PhotoAttachment.ownerInspection] or [PhotoAttachment.ownerMaintenance].
  final String ownerType;
  final String ownerId;
  final String title;

  /// Also offer video capture (native only).
  final bool allowVideo;

  @override
  State<PhotoAttachmentsSection> createState() =>
      _PhotoAttachmentsSectionState();
}

class _PhotoAttachmentsSectionState extends State<PhotoAttachmentsSection> {
  /// Thumbnails shown inline; the rest are behind the gallery modal.
  static const int _previewCount = 5;

  List<PhotoAttachment> _photos = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoAttachmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different record must never keep showing the previous record's photos.
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.ownerType != widget.ownerType) {
      setState(() {
        _photos = const [];
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final ownerType = widget.ownerType;
    final ownerId = widget.ownerId;
    final photos = await PhotoService.instance.listForOwner(ownerType, ownerId);
    // Drop results for an owner we've since moved away from.
    if (!mounted || ownerId != widget.ownerId || ownerType != widget.ownerType) {
      return;
    }
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  Future<void> _openGallery() async {
    await showPhotoGallery(
      context,
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
      title: widget.title,
      allowVideo: widget.allowVideo,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _photos.take(_previewCount).toList();
    final extra = _photos.length - preview.length;

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
                  _photos.isEmpty
                      ? widget.title
                      : '${widget.title} (${_photos.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : _openGallery,
                  icon: Icon(_photos.isEmpty
                      ? Icons.add_a_photo_outlined
                      : Icons.photo_library_outlined),
                  label: Text(_photos.isEmpty ? 'Add' : 'Manage'),
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
            else if (_photos.isEmpty)
              Text(
                'No photos yet for this record.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final photo in preview)
                    _Thumbnail(photo: photo, onTap: _openGallery),
                  if (extra > 0) _MoreTile(count: extra, onTap: _openGallery),
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
    final bytes =
        photo.isVideo ? null : PhotoService.instance.loadBytesSync(photo);

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
            child: photo.isVideo
                ? Container(
                    color: Colors.black87,
                    child: const Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 36),
                  )
                : bytes != null
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

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$count more photos',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Text('+$count', style: theme.textTheme.titleMedium),
        ),
      ),
    );
  }
}
