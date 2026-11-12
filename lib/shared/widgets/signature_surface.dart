import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/signature_palette.dart';

/// A light "paper" surface for drawing or showing a signature.
///
/// Stays paper-white in both app themes (see [SignaturePalette]) with a
/// clearly visible outline so it looks intentional on a dark background.
///
/// As a pad (no [fixedHeight]) it fills the available width up to [maxWidth]
/// and takes a height between [minHeight] and [maxHeight] from the width, so
/// it is comfortable to draw on a phone and does not become a huge slab on a
/// tablet. Put a transparent-background `Signature` in [child]; the paper,
/// baseline and [hint] are painted underneath it.
class SignaturePaper extends StatelessWidget {
  const SignaturePaper({
    super.key,
    this.child,
    this.hint,
    this.fixedHeight,
    this.maxWidth = defaultMaxWidth,
    this.minHeight = defaultMinHeight,
    this.maxHeight = 240,
    this.aspectRatio = 2.4,
    this.showBaseline = true,
    this.semanticLabel,
    this.semanticHint,
  });

  static const double defaultMaxWidth = 560;
  static const double defaultMinHeight = 140;

  /// Drawn on top of the paper (usually the `Signature` widget).
  final Widget? child;

  /// Text such as "Sign here" shown under the baseline.
  final String? hint;

  /// Use for read-only previews; skips the width-based height.
  final double? fixedHeight;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
  final double aspectRatio;
  final bool showBaseline;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget paper(double height) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SignaturePalette.paper,
            borderRadius: AppRadius.fieldAll,
            border: Border.all(color: SignaturePalette.outline, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showBaseline || hint != null)
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (showBaseline)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: SignaturePalette.hint,
                            ),
                          if (hint != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                hint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: SignaturePalette.hint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (child != null) child!,
              ],
            ),
          ),
        ),
      );
    }

    Widget result = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: fixedHeight != null
            ? paper(fixedHeight!)
            : LayoutBuilder(
                builder: (context, c) {
                  final w = c.hasBoundedWidth ? c.maxWidth : maxWidth;
                  return paper((w / aspectRatio).clamp(minHeight, maxHeight));
                },
              ),
      ),
    );
    if (semanticLabel != null || semanticHint != null) {
      result = Semantics(
        label: semanticLabel,
        hint: semanticHint,
        container: true,
        child: result,
      );
    }
    return result;
  }
}

/// A saved signature (PNG bytes) shown on [SignaturePaper] so dark ink never
/// lands on a dark background. Shows [emptyLabel] when there are no bytes.
class SignatureImagePreview extends StatelessWidget {
  const SignatureImagePreview({
    super.key,
    required this.bytes,
    this.height = 90,
    this.emptyLabel = 'Not signed',
  });

  final Uint8List? bytes;
  final double height;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SignaturePalette.hint,
        );
    Widget label(String text) => Center(child: Text(text, style: style));
    final b = bytes;
    return SignaturePaper(
      fixedHeight: height,
      showBaseline: false,
      child: b == null || b.isEmpty
          ? label(emptyLabel)
          : Padding(
              padding: const EdgeInsets.all(4),
              child: Image.memory(
                b,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => label('Signature unavailable'),
              ),
            ),
    );
  }
}
