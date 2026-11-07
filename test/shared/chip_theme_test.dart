import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/app_theme.dart';

void main() {
  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('${entry.key}: chip labels have a visible colour',
        (tester) async {
      final theme = entry.value;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Wrap(children: [
            FilterChip(
                label: const Text('filter'), selected: false, onSelected: (_) {}),
            FilterChip(
                label: const Text('filter on'),
                selected: true,
                onSelected: (_) {}),
            ActionChip(label: const Text('action'), onPressed: () {}),
            ChoiceChip(
                label: const Text('choice'), selected: true, onSelected: (_) {}),
          ]),
        ),
      ));

      Color colorOf(String text) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        return paragraph.text.style!.color!;
      }

      final bg = theme.colorScheme.surface;
      for (final label in ['filter', 'filter on', 'action', 'choice']) {
        final c = colorOf(label);
        // Not a washed-out colour: reasonable contrast against the page.
        final contrast = (c.computeLuminance() - bg.computeLuminance()).abs();
        expect(contrast, greaterThan(0.3), reason: '$label is hard to read');
      }
    });
  }
}
