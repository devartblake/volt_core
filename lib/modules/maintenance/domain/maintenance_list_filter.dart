import '../infra/models/maintenance_record.dart';

/// Status filter on the maintenance list.
enum MaintenanceStatusFilter {
  all('All'),
  inProgress('In progress'),
  completed('Completed');

  const MaintenanceStatusFilter(this.label);

  final String label;

  bool matches(MaintenanceRecord r) => switch (this) {
        all => true,
        inProgress => !r.completed,
        completed => r.completed,
      };
}

/// Records matching [filter], in their original order.
List<MaintenanceRecord> filterMaintenance(
  Iterable<MaintenanceRecord> records,
  MaintenanceStatusFilter filter,
) =>
    [
      for (final r in records)
        if (filter.matches(r)) r,
    ];
