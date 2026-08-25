import 'package:flutter/material.dart';

/// Records the technician's conclusion for one checklist item.
///
/// The switch answers *whether* something passed; this answers *what was
/// found*. Those are different pieces of evidence, and a single free-text
/// Notes box at the bottom of the form cannot say which item a remark belongs
/// to — which is exactly the problem when the report is read months later.
///
/// Returns the new text on save, or null when dismissed. An empty result is a
/// deliberate clear, so callers should treat "" as "remove the note" rather
/// than as no-change.
class ChecklistNoteDialog extends StatefulWidget {
  const ChecklistNoteDialog({
    super.key,
    required this.itemLabel,
    required this.answer,
    this.initialText = '',
  });

  /// The checklist row this belongs to, shown so the technician can see which
  /// item they are annotating without dismissing the dialog.
  final String itemLabel;

  /// Current switch position, echoed for the same reason.
  final bool answer;

  final String initialText;

  /// Convenience wrapper; returns null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String itemLabel,
    required bool answer,
    String initialText = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ChecklistNoteDialog(
        itemLabel: itemLabel,
        answer: answer,
        initialText: initialText,
      ),
    );
  }

  @override
  State<ChecklistNoteDialog> createState() => _ChecklistNoteDialogState();
}

class _ChecklistNoteDialogState extends State<ChecklistNoteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answerColor = widget.answer ? scheme.primary : scheme.onSurfaceVariant;

    return AlertDialog(
      title: const Text('Conclusion'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.itemLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: answerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: answerColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    widget.answer ? 'YES' : 'NO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: answerColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Findings / conclusion',
                hintText: 'What was observed, and what follow-up is needed?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.initialText.trim().isNotEmpty)
          TextButton(
            // Clearing is a save of empty text, not a dismissal — otherwise
            // there is no way to take back a note once written.
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
