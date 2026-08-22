import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/form_fields/labeled_field.dart';

/// Rebuilds a [LabeledField] with a new value, the way a form section does
/// when the entity it renders changes.
class _Rebuildable extends StatefulWidget {
  const _Rebuildable({required this.keyed});

  /// Whether the field carries a value-derived key.
  final bool keyed;

  @override
  State<_Rebuildable> createState() => _RebuildableState();
}

class _RebuildableState extends State<_Rebuildable> {
  String value = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            LabeledField(
              key: widget.keyed ? ValueKey('date|$value') : null,
              label: 'Date',
              value: value,
              readOnly: true,
            ),
            TextButton(
              onPressed: () => setState(() => value = '2026-01-31'),
              child: const Text('set'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('LabeledField', () {
    testWidgets('required marks the label and validates as empty', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: const LabeledField(label: 'Site code', required: true),
            ),
          ),
        ),
      );

      expect(find.text('Site code *'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Site code is required'), findsOneWidget);
    });

    testWidgets('readOnly still delivers onTap', (tester) async {
      // The maintenance signature date field relies on this: it dropped its
      // InkWell + IgnorePointer wrapper in favour of readOnly + onTap, so if
      // a read-only field ever stopped reporting taps the date picker would
      // silently never open.
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LabeledField(
              label: 'Date Signed',
              readOnly: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a keyed field shows a new value after rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(const _Rebuildable(keyed: true));
      expect(find.text('2026-01-31'), findsNothing);

      await tester.tap(find.text('set'));
      await tester.pumpAndSettle();

      expect(find.text('2026-01-31'), findsOneWidget);
    });

    testWidgets('an unkeyed field adopts the new value too', (tester) async {
      // This used to be the opposite assertion. A TextFormField seeds its
      // controller from `initialValue` exactly once, so the field kept showing
      // whatever it was first built with while the entity moved on — the
      // stale-date bug. Call sites papered over it with a value-derived key,
      // which is not an option for an editable field: rebuilding it on every
      // keystroke would drop focus and the cursor.
      //
      // LabeledField now owns its controller and adopts an externally changed
      // value in didUpdateWidget, so correctness no longer depends on the
      // caller remembering a key.
      await tester.pumpWidget(const _Rebuildable(keyed: false));

      await tester.tap(find.text('set'));
      // Updating a TextEditingController inside didUpdateWidget used to mark
      // the enclosing Form dirty while it was building. The update now lands
      // post-frame, so the rebuild stays exception-free.
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      expect(find.text('2026-01-31'), findsOneWidget);
    });

    testWidgets(
      'typing is not disturbed by the parent echoing the value back',
      (tester) async {
        // The guard on the sync above: while the user types, onChanged has
        // already told the parent, so the value coming back equals the field's
        // text and didUpdateWidget must leave the selection alone.
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LabeledField(label: 'Site code', controller: controller),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'SITE-42');
        await tester.pump();

        expect(controller.text, 'SITE-42');
        expect(controller.selection.baseOffset, 'SITE-42'.length);
      },
    );

    testWidgets(
      'dense drops the outer padding used by the standalone variant',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  LabeledField(label: 'Roomy'),
                  LabeledField(label: 'Tight', dense: true),
                ],
              ),
            ),
          ),
        );

        Padding outerPadding(String label) {
          return tester.widget<Padding>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Padding))
                .last,
          );
        }

        expect(
          outerPadding('Roomy').padding,
          const EdgeInsets.symmetric(vertical: 8),
        );
        expect(outerPadding('Tight').padding, EdgeInsets.zero);
      },
    );
  });
}
