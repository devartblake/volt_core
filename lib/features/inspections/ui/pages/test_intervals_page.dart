import 'package:flutter/material.dart';
import 'package:voltcore/shared/widgets/responsive_scaffold.dart';

import '../../data/models/test_interval_record.dart';
import '../../data/sources/hive_boxes.dart';

class TestIntervalsPage extends StatefulWidget {
  final String inspectionId;

  const TestIntervalsPage({
    super.key,
    required this.inspectionId,
  });

  @override
  State<TestIntervalsPage> createState() => _TestIntervalsPageState();
}

class _TestIntervalsPageState extends State<TestIntervalsPage> {
  late List<TestIntervalRecord> _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final box = HiveBoxes.testIntervals;
    _rows = box.values
        .where((r) => r.inspectionId == widget.inspectionId)
        .cast<TestIntervalRecord>()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Test Reading Intervals'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null,
      ),
      body: _rows.isEmpty
          ? const Center(child: Text('No interval readings recorded.'))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: _rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = _rows[index];
              return Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interval ${r.index + 1}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _kv('Target kW', r.realtimeKwTarget),
                          _kv('RPM', r.engineRpm),
                          _kv('Hz', r.frequencyHz),
                          _kv('Eng. Water °F', r.engineWaterF),
                          _kv('Rad. Water °F', r.radiatorWaterF),
                          _kv('Oil Temp °F', r.engineOilTempF),
                          _kv('Oil PSI', r.engineOilPsi),
                          _kv('Panel V', r.panelVolt),
                          _kv('Measured V', r.measuredVolt),
                          _kv('Panel A', r.panelAmp),
                          _kv('Measured A', r.measuredAmp),
                          _kv('Panel kW', r.panelKw),
                          _kv('Measured kW', r.measuredKw),
                          _kv('Battery V', r.batteryVolt),
                          _kv('Fuel PSI', r.fuelPressure),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
