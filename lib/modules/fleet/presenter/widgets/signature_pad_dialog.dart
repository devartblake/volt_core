import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Capture one signature, returning its PNG bytes or null if cancelled.
///
/// A dialog rather than a section on the form: an asset receipt is signed by
/// two different people, often minutes apart and sometimes by handing the
/// tablet over. Putting each signature behind a deliberate "Sign" action makes
/// whose turn it is unambiguous, which an always-visible pad does not.
Future<Uint8List?> showSignaturePad({
  required BuildContext context,
  required String title,
  String? subtitle,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SignaturePadDialog(title: title, subtitle: subtitle),
  );
}

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );

  bool _hasInk = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Drives the Save button. Without it the button is live over an empty pad
    // and a stray tap stores a blank PNG that looks like a signature in the
    // database and prints as nothing.
    _controller.addListener(_onStroke);
  }

  void _onStroke() {
    final hasInk = _controller.isNotEmpty;
    if (hasInk != _hasInk) setState(() => _hasInk = hasInk);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onStroke)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_hasInk || _saving) return;
    setState(() => _saving = true);

    final bytes = await _controller.toPngBytes();
    if (!mounted) return;

    if (bytes == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _controller,
                  height: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign above',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => _controller.clear(),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hasInk && !_saving ? _save : null,
          child: const Text('Save signature'),
        ),
      ],
    );
  }
}
