import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A photo thumbnail that decodes at display size instead of full resolution.
///
/// Flutter's image cache keys on the resized provider, so a thumbnail that is
/// rebuilt while scrolling is not decoded again. Give [size] for a fixed
/// square, or leave it null to size from the available width. A missing or
/// undecodable file shows a quiet broken-image placeholder.
class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage.memory(
    Uint8List this.bytes, {
    super.key,
    this.size,
    this.fit = BoxFit.cover,
  }) : file = null;

  const ThumbnailImage.file(
    File this.file, {
    super.key,
    this.size,
    this.fit = BoxFit.cover,
  }) : bytes = null;

  final Uint8List? bytes;
  final File? file;
  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    if (size != null) return _image(context, size!, dpr);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth && c.maxWidth.isFinite ? c.maxWidth : 120.0;
        return _image(context, w, dpr);
      },
    );
  }

  Widget _image(BuildContext context, double logical, double dpr) {
    final px = (logical * dpr).round().clamp(32, 1024);
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
    Widget errorBuilder(BuildContext _, Object __, StackTrace? ___) =>
        placeholder;
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: fit,
        cacheWidth: px,
        gaplessPlayback: true,
        errorBuilder: errorBuilder,
      );
    }
    return Image.file(
      file!,
      fit: fit,
      cacheWidth: px,
      gaplessPlayback: true,
      errorBuilder: errorBuilder,
    );
  }
}
