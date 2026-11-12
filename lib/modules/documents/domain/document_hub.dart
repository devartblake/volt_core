import '../../../core/services/storage/pdf_library_service.dart';

/// Type filter shown as chips on the Documents hub.
enum DocumentTypeFilter { all, inspections, maintenance, vehicles, other }

extension DocumentTypeFilterX on DocumentTypeFilter {
  String get label => switch (this) {
        DocumentTypeFilter.all => 'All',
        DocumentTypeFilter.inspections => 'Inspections',
        DocumentTypeFilter.maintenance => 'Maintenance',
        DocumentTypeFilter.vehicles => 'Vehicles',
        DocumentTypeFilter.other => 'Other',
      };

  PdfCategory? get category => switch (this) {
        DocumentTypeFilter.all => null,
        DocumentTypeFilter.inspections => PdfCategory.inspection,
        DocumentTypeFilter.maintenance => PdfCategory.maintenance,
        DocumentTypeFilter.vehicles => PdfCategory.vehicle,
        DocumentTypeFilter.other => PdfCategory.other,
      };

  bool matches(PdfDocumentInfo doc) =>
      category == null || doc.category == category;
}

enum DocumentSort { newest, name, size }

extension DocumentSortX on DocumentSort {
  String get label => switch (this) {
        DocumentSort.newest => 'Newest',
        DocumentSort.name => 'Name',
        DocumentSort.size => 'Size',
      };
}

/// Documents whose file name contains [query] (case-insensitive).
List<PdfDocumentInfo> searchDocuments(
  List<PdfDocumentInfo> docs,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.of(docs);
  return docs.where((d) => d.name.toLowerCase().contains(q)).toList();
}

/// Documents of the given type.
List<PdfDocumentInfo> filterByType(
  List<PdfDocumentInfo> docs,
  DocumentTypeFilter filter,
) =>
    docs.where(filter.matches).toList();

/// Count per filter chip (All counts everything).
Map<DocumentTypeFilter, int> countByType(List<PdfDocumentInfo> docs) => {
      for (final f in DocumentTypeFilter.values)
        f: docs.where(f.matches).length,
    };

/// Returns a sorted copy. Ties fall back to newest first.
List<PdfDocumentInfo> sortDocuments(
  List<PdfDocumentInfo> docs,
  DocumentSort sort,
) {
  int newest(PdfDocumentInfo a, PdfDocumentInfo b) =>
      b.modified.compareTo(a.modified);
  final out = List.of(docs);
  switch (sort) {
    case DocumentSort.newest:
      out.sort(newest);
    case DocumentSort.name:
      out.sort((a, b) {
        final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return c != 0 ? c : newest(a, b);
      });
    case DocumentSort.size:
      out.sort((a, b) {
        final c = b.sizeBytes.compareTo(a.sizeBytes);
        return c != 0 ? c : newest(a, b);
      });
  }
  return out;
}

/// A dated section of the list.
class DocumentGroup {
  const DocumentGroup(this.label, this.documents);
  final String label;
  final List<PdfDocumentInfo> documents;
}

const kDocumentGroupLabels = ['Today', 'This week', 'This month', 'Older'];

/// Buckets [docs] (kept in the given order) into Today / This week (since
/// Monday) / This month / Older. Empty buckets are omitted. Dates in the
/// future count as Today.
List<DocumentGroup> groupByDate(List<PdfDocumentInfo> docs, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month);

  final buckets = <String, List<PdfDocumentInfo>>{
    for (final l in kDocumentGroupLabels) l: [],
  };
  for (final d in docs) {
    final m = d.modified;
    final day = DateTime(m.year, m.month, m.day);
    final label = !day.isBefore(today)
        ? 'Today'
        : !day.isBefore(weekStart)
            ? 'This week'
            : !day.isBefore(monthStart)
                ? 'This month'
                : 'Older';
    buckets[label]!.add(d);
  }
  return [
    for (final l in kDocumentGroupLabels)
      if (buckets[l]!.isNotEmpty) DocumentGroup(l, buckets[l]!),
  ];
}

/// Documents last modified more than [days] days before [now].
List<PdfDocumentInfo> documentsOlderThan(
  List<PdfDocumentInfo> docs,
  DateTime now, {
  int days = 90,
}) {
  final cutoff = now.subtract(Duration(days: days));
  return docs.where((d) => d.modified.isBefore(cutoff)).toList();
}

int totalBytes(Iterable<PdfDocumentInfo> docs) =>
    docs.fold(0, (sum, d) => sum + d.sizeBytes);

/// Compact size with one decimal: "512 B", "3.4 KB", "8.4 MB".
String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// "12 documents, 8.4 MB".
String summaryLabel(List<PdfDocumentInfo> docs) {
  final n = docs.length;
  return '$n ${n == 1 ? 'document' : 'documents'}, '
      '${formatSize(totalBytes(docs))}';
}
