import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/thumbnail_image.dart';
import '../../domain/catalog_part.dart';
import '../../infra/part_image_store.dart';

/// A part's product photo: the cached file, else downloaded once and cached,
/// else a neutral placeholder. Never throws. With [size] it is a fixed square;
/// without, it fills the space it is given.
class PartImage extends ConsumerStatefulWidget {
  const PartImage(
      {super.key, required this.part, this.size, this.fit = BoxFit.cover});

  final CatalogPart part;
  final double? size;
  final BoxFit fit;

  @override
  ConsumerState<PartImage> createState() => _PartImageState();
}

class _PartImageState extends ConsumerState<PartImage> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(PartImage old) {
    super.didUpdateWidget(old);
    if (old.part.id != widget.part.id ||
        old.part.imagePath != widget.part.imagePath) {
      _start();
    }
  }

  void _start() {
    final path = widget.part.imagePath;
    if (path == null || path.isEmpty) {
      _future = null;
      return;
    }
    final store = ref.read(partImageStoreProvider);
    _future = () async {
      try {
        return await store.load(widget.part);
      } catch (_) {
        return null;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder() => ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.inventory_2_outlined,
                color: theme.colorScheme.onSurfaceVariant),
          ),
        );
    final future = _future;
    final Widget child = future == null
        ? placeholder()
        : FutureBuilder<Uint8List?>(
            future: future,
            builder: (context, snap) {
              final bytes = snap.data;
              if (snap.connectionState == ConnectionState.done &&
                  bytes != null &&
                  bytes.isNotEmpty) {
                return ThumbnailImage.memory(bytes,
                    size: widget.size, fit: widget.fit);
              }
              return placeholder();
            },
          );
    if (widget.size == null) return child;
    return SizedBox.square(dimension: widget.size, child: child);
  }
}

/// Small rounded thumbnail for list rows.
class PartThumb extends StatelessWidget {
  const PartThumb({super.key, required this.part, this.size = 48});
  final CatalogPart part;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PartImage(part: part, size: size),
      );
}

/// Full-screen, pinch-to-zoom view of a part's photo.
Future<void> showPartImageViewer(BuildContext context, CatalogPart part) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            key: const Key('part_image_viewer'),
            maxScale: 5,
            child: PartImage(part: part, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton.filledTonal(
              key: const Key('part_image_close'),
              tooltip: 'Close',
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ]),
    ),
  );
}
