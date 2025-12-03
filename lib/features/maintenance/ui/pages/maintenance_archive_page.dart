import 'package:flutter/material.dart';
import 'package:voltcore/shared/widgets/responsive_scaffold.dart';

import '../../data/models/maintenance_record.dart';
import '../../data/sources/hive_boxes_maintenance.dart';

class MaintenanceArchivePage extends StatefulWidget {
  /// Optional pre-filtered records – if null we load from the box.
  final List<MaintenanceRecord>? initialRecords;

  const MaintenanceArchivePage({
    super.key,
    this.initialRecords,
  });

  @override
  State<MaintenanceArchivePage> createState() => _MaintenanceArchivePageState();
}

class _MaintenanceArchivePageState extends State<MaintenanceArchivePage> {
  late List<MaintenanceRecord> _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (widget.initialRecords != null) {
      _records = List<MaintenanceRecord>.from(widget.initialRecords!);
    } else {
      final box = MaintenanceBoxes.maintenance;
      _records = box.values.cast<MaintenanceRecord>().toList()
        ..sort((a, b) {
          final da = a.dateOfService ?? a.createdAt;
          final db = b.dateOfService ?? b.createdAt;
          return db.compareTo(da); // newest first
        });
    }

    // If you later add an `archived` flag, you can change to:
    // _records = _records.where((m) => m.archived).toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Maintenance Archive'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null,
      ),
      body: _records.isEmpty
          ? const Center(child: Text('No archived maintenance records.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final m = _records[index];
          final date = m.dateOfService ?? m.createdAt;
          return ListTile(
            leading: const Icon(Icons.build_outlined),
            title: Text(
              '${m.siteCode} – ${m.generatorMake} ${m.generatorModel}'
                  .trim(),
            ),
            subtitle: Text(
              '${_fmtDate(date)} · Technician: ${m.technicianName}',
            ),
            onTap: () {
              // You can navigate to your existing MaintenanceDetailPage
              // once it’s wired, for example:
              // context.pushNamed('maintenance_detail', params: {'id': m.id});
            },
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
