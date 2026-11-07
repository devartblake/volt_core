import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/section_materials.dart';
import 'package:voltcore/shared/widgets/form_fields/labeled_field.dart';

/// The Materials step now embeds the parts editor, which reads and writes its
/// parts through this store; an empty in-memory one keeps these tests about the
/// date fields (a Hive write would never complete on the test clock).
class _NoParts extends MaterialsRepository {
  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async => const [];

  @override
  Future<List<MaterialItem>> save(
    MaterialOwner owner,
    List<MaterialItem> items,
  ) async =>
      items;
}

/// Hosts a section the way the form does: the parent owns the entity and
/// rebuilds the section with the updated value, which is what the form's
/// `_onSectionChanged` does before queuing a draft write.
class _Host extends StatefulWidget {
  const _Host({required this.onChanged});

  final ValueChanged<InspectionEntity> onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  InspectionEntity model = InspectionEntity.newDraft();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [materialsRepositoryProvider.overrideWithValue(_NoParts())],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SectionMaterials(
              model: model,
              onChanged: (updated) {
                setState(() => model = updated);
                widget.onChanged(updated);
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('SectionMaterials', () {
    testWidgets('uses the shared LabeledField', (tester) async {
      await tester.pumpWidget(_Host(onChanged: (_) {}));
      expect(find.byType(LabeledField), findsWidgets);
    });

    testWidgets('picking a date emits onChanged so autosave still fires',
        (tester) async {
      InspectionEntity? emitted;
      await tester.pumpWidget(_Host(onChanged: (e) => emitted = e));

      // Open the picker from the field itself.
      await tester.tap(find.text('Last Full Service Date').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The guardrail from the migration plan: a field that stops firing
      // onChanged silently disables draft autosave for that value.
      expect(emitted, isNotNull);
      expect(emitted!.lastServiceDate, isNotEmpty);
    });

    testWidgets('a date on a listed part keeps the older date field in step',
        (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      InspectionEntity? emitted;
      await tester.pumpWidget(_Host(onChanged: (e) => emitted = e));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oil filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add oil filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not recorded'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The inspection PDF and older records still read this field.
      expect(emitted, isNotNull);
      expect(emitted!.oilFilterChangeDate, isNotEmpty);
    });

    testWidgets('the picked date is actually displayed after rebuild',
        (tester) async {
      await tester.pumpWidget(_Host(onChanged: (_) {}));

      await tester.tap(find.text('Last Full Service Date').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // A TextFormField built from `initialValue` keeps its original text
      // across rebuilds, so without a value-derived key the field would still
      // read empty here even though the entity changed.
      final today = DateTime.now().toIso8601String().split('T').first;
      expect(find.text(today), findsWidgets);
    });

    testWidgets('clearing a date emits an empty value', (tester) async {
      InspectionEntity? emitted;
      await tester.pumpWidget(_Host(onChanged: (e) => emitted = e));

      await tester.tap(find.text('Last Full Service Date').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(emitted!.lastServiceDate, isNotEmpty);

      // The clear button only appears once a date is set.
      await tester.tap(find.byTooltip('Clear date').first);
      await tester.pumpAndSettle();

      expect(emitted!.lastServiceDate, isEmpty);
    });
  });
}
