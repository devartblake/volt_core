/// Simple interval entity used for nameplate/testing intervals.
class IntervalEntity {
  final String id;
  final String inspectionId;
  final DateTime timestamp;
  final String label;
  final double? loadPercent;
  final String? notes;

  const IntervalEntity({
    required this.id,
    required this.inspectionId,
    required this.timestamp,
    this.label = '',
    this.loadPercent,
    this.notes,
  });

  IntervalEntity copyWith({
    String? id,
    String? inspectionId,
    DateTime? timestamp,
    String? label,
    double? loadPercent,
    String? notes,
  }) {
    return IntervalEntity(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      timestamp: timestamp ?? this.timestamp,
      label: label ?? this.label,
      loadPercent: loadPercent ?? this.loadPercent,
      notes: notes ?? this.notes,
    );
  }
}
