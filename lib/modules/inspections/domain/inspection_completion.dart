import '../../materials/domain/material_item.dart';
import 'entities/inspection_entity.dart';
import 'inspection_checklist.dart';

/// One part the Parts & Materials list must name before an inspection counts
/// as finished.
enum PartRequirement {
  airFilter('Air filter', {MaterialSlot.airFilter}),
  fuelFilter('Fuel filter', {MaterialSlot.fuelFilter}),

  /// Either slot satisfies it.
  oilOrLubeFilter(
      'Oil or lube filter', {MaterialSlot.oilFilter, MaterialSlot.lubeFilter}),
  coolantFilter('Coolant filter', {MaterialSlot.coolantFilter}),
  battery('Battery', {MaterialSlot.battery});

  const PartRequirement(this.label, this.slots);

  final String label;
  final Set<MaterialSlot> slots;

  /// Met when at least one item in a matching slot has a part number that is
  /// not blank or whitespace. Name, manufacturer and quantity do not count.
  bool isMetBy(List<MaterialItem> items) =>
      items.any((m) => slots.contains(m.slot) && m.hasPartNumber);
}

/// Whether an inspection counts as FINISHED, and if not, why.
///
/// Finished needs both:
/// * the post-inspection checklist at least 50% done ([checklistMet]), and
/// * every [PartRequirement] met.
///
/// Pure and computed on demand: nothing is stored, so records saved before
/// this rule existed are judged by it too, and saving a draft is never
/// blocked by it.
class InspectionCompletion {
  InspectionCompletion._({
    required this.checklistAnswered,
    required this.checklistTotal,
    required this.parts,
  });

  /// Builds from raw counts (an empty checklist is met by definition).
  factory InspectionCompletion.fromCounts({
    required int answered,
    required int total,
    required List<MaterialItem> items,
  }) =>
      InspectionCompletion._(
        checklistAnswered: answered,
        checklistTotal: total,
        parts: {for (final r in PartRequirement.values) r: r.isMetBy(items)},
      );

  /// Computes the state from [inspection] and its Parts & Materials [items].
  factory InspectionCompletion.of(
    InspectionEntity inspection,
    List<MaterialItem> items,
  ) {
    // Answered = ticked, or unticked with a written conclusion (the same
    // meaning as the "unanswered" list).
    final answered = kInspectionChecklist
        .where((c) =>
            c.read(inspection) || inspection.checklistNoteFor(c.key).isNotEmpty)
        .length;
    return InspectionCompletion._(
      checklistAnswered: answered,
      checklistTotal: kInspectionChecklist.length,
      parts: {for (final r in PartRequirement.values) r: r.isMetBy(items)},
    );
  }

  /// Checklist items done (ticked or concluded).
  final int checklistAnswered;
  final int checklistTotal;

  /// Each requirement and whether it is met, in display order.
  final Map<PartRequirement, bool> parts;

  /// Smallest number of items that meets the 50% bar: `ceil(total / 2)`.
  int get checklistNeeded => (checklistTotal + 1) ~/ 2;

  /// Fraction done; 1.0 when the checklist has no items.
  double get checklistRatio =>
      checklistTotal == 0 ? 1.0 : checklistAnswered / checklistTotal;

  /// Exactly 50% counts (`answered * 2 >= total`). An empty checklist is met.
  bool get checklistMet => checklistAnswered * 2 >= checklistTotal;

  List<PartRequirement> get missingParts =>
      [for (final e in parts.entries) if (!e.value) e.key];

  bool get partsMet => missingParts.isEmpty;

  bool get isFinished => checklistMet && partsMet;

  /// Plain-language reasons it is not finished; empty when finished.
  List<String> get reasons => [
        if (!checklistMet)
          'Post-inspection checklist $checklistAnswered of $checklistTotal '
              'done ($checklistNeeded needed)',
        for (final r in missingParts) 'Missing part number: ${r.label}',
      ];

  /// How many things are left (the checklist counts as one).
  int get remainingCount => reasons.length;
}
