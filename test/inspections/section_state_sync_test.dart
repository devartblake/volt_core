import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/section_location_safety.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/section_materials.dart';

/// Mirrors `inspection_form_page`: one entity owned by the parent, every
/// section rendered from it, every section's `onChanged` replacing it.
class _Form extends StatefulWidget {
  const _Form({required this.onChanged});

  final ValueChanged<InspectionEntity> onChanged;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  InspectionEntity model = InspectionEntity.newDraft();

  /// Stands in for the form page restoring an autosaved draft.
  void replaceModel(InspectionEntity next) => setState(() => model = next);

  void _onSectionChanged(InspectionEntity updated) {
    setState(() => model = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SectionLocationSafety(model: model, onChanged: _onSectionChanged),
              SectionMaterials(model: model, onChanged: _onSectionChanged),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  /// Both sections on screen at once, so taps don't fight the scroll position.
  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
  }

  testWidgets(
      "editing a second section does not discard the first section's data",
      (tester) async {
    // The data-loss bug: each section copied `widget.model` into a field in
    // initState and never resynced, so its `copyWith` was applied to the
    // entity as it looked when the form first built. Whichever section the
    // technician edited last silently overwrote every other section — the
    // saved inspection came out blank apart from that one, which is why
    // inspections had no address or site code to show as a title.
    late InspectionEntity latest;
    await pumpTall(tester, _Form(onChanged: (e) => latest = e));

    // Section one: flip a switch.
    await tester.tap(find.text('Area clear of obstructions'));
    await tester.pumpAndSettle();
    expect(latest.areaClear, isTrue);

    // Section two: pick a date, as the materials/signature sections do at the
    // end of a real inspection.
    await tester.tap(find.text('Last Full Service Date').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(latest.lastServiceDate, isNotEmpty);

    // The regression: section two must build its update from the *current*
    // entity, not from the empty draft it first rendered.
    expect(
      latest.areaClear,
      isTrue,
      reason: 'section two clobbered the switch set in section one',
    );
  });

  testWidgets('a section re-renders when the parent replaces the entity',
      (tester) async {
    // The display half of the same problem: a section that ignores a new
    // `widget.model` keeps showing stale values after a draft is restored.
    await pumpTall(tester, _Form(onChanged: (_) {}));
    final state = tester.state<_FormState>(find.byType(_Form));

    state.replaceModel(state.model.copyWith(lastServiceDate: '2024-03-09'));
    await tester.pumpAndSettle();

    expect(find.text('2024-03-09'), findsOneWidget);
  });
}
