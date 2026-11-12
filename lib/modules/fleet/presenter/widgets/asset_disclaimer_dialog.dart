import 'package:flutter/material.dart';

import '../../domain/entities/asset_disclaimer.dart';

/// The terms a driver accepts before signing for a vehicle's tools.
///
/// Presented as a blocking modal, on purpose. The paper prints the five clauses
/// in a box above the signature line, where a person signing has at least
/// glanced at them; a checkbox labelled "I agree to the terms" reproduces the
/// signature without reproducing the reading. So: the text is on screen, the
/// Accept button is disabled until it has been scrolled to the end, and there
/// is no way past it except Accept or Cancel.
///
/// Returns true when accepted, false or null otherwise.
Future<bool?> showAssetDisclaimerDialog({
  required BuildContext context,
  required AssetDisclaimer disclaimer,
  required String operatorName,
}) {
  return showDialog<bool>(
    context: context,
    // Dismissing by tapping outside would be indistinguishable from accepting
    // to anyone watching over a shoulder.
    barrierDismissible: false,
    builder: (_) => _AssetDisclaimerDialog(
      disclaimer: disclaimer,
      operatorName: operatorName,
    ),
  );
}

class _AssetDisclaimerDialog extends StatefulWidget {
  const _AssetDisclaimerDialog({
    required this.disclaimer,
    required this.operatorName,
  });

  final AssetDisclaimer disclaimer;
  final String operatorName;

  @override
  State<_AssetDisclaimerDialog> createState() => _AssetDisclaimerDialogState();
}

class _AssetDisclaimerDialogState extends State<_AssetDisclaimerDialog> {
  final _scroll = ScrollController();

  /// Starts false and flips once the text has been scrolled to the bottom.
  /// Seeded in the first frame because a short disclaimer on a tall tablet may
  /// never scroll at all — and then there is nothing to wait for.
  bool _readToEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  void _seed() {
    if (!mounted || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      setState(() => _readToEnd = true);
    }
  }

  void _onScroll() {
    if (_readToEnd || !_scroll.hasClients) return;
    // A few pixels of slack: momentum scrolling often stops just shy of the
    // exact bottom, and refusing to enable the button then is maddening.
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 12) {
      setState(() => _readToEnd = true);
    }
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disclaimer = widget.disclaimer;
    final name = widget.operatorName.trim();

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(disclaimer.title),
          const SizedBox(height: 4),
          Text(
            'Version ${disclaimer.version}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        // Bounded so the clause list scrolls inside the dialog rather than
        // pushing the buttons off a phone screen.
        height: 420,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty) ...[
                  Text(
                    name,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(disclaimer.intro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                for (var i = 0; i < disclaimer.clauses.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${disclaimer.clauses[i].heading}: ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: disclaimer.clauses[i].body),
                              ],
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  disclaimer.closing,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _readToEnd ? () => Navigator.of(context).pop(true) : null,
          child: Text(_readToEnd ? 'Accept' : 'Scroll to accept'),
        ),
      ],
    );
  }
}
