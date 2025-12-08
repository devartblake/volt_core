import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../infra/models/nameplate_data.dart';
import '../../../load_test/infra/models/test_interval_record.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';

class NameplateIntervalsPage extends ConsumerStatefulWidget {
  final String inspectionId;
  const NameplateIntervalsPage({super.key, required this.inspectionId});

  @override
  ConsumerState<NameplateIntervalsPage> createState() =>
      _NameplateIntervalsPageState();
}

class _NameplateIntervalsPageState
    extends ConsumerState<NameplateIntervalsPage> {
  NameplateData? _np;

  @override
  void initState() {
    super.initState();
    _np = HiveBoxes.nameplates.values.firstWhere(
          (n) => n.inspectionId == widget.inspectionId,
      orElse: () => NameplateData(
        id: const Uuid().v4(),
        inspectionId: widget.inspectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = HiveBoxes.testIntervals.values
        .where((e) => e.inspectionId == widget.inspectionId)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Scaffold(
      appBar: AppBar(title: const Text('Nameplate & Intervals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _nameplateCard(),
          const SizedBox(height: 16),
          _intervalsCard(rows),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _saveNameplate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved')),
            );
          }
        },
        label: const Text('Save'),
        icon: const Icon(Icons.save),
      ),
    );
  }

  Widget _nameplateCard() {
    final m = _np!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nameplate Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _row2(
              _t('Generator Mfr.', m.generatorMfr,
                      (v) => m.generatorMfr = v),
              _t('Model No.', m.generatorModel,
                      (v) => m.generatorModel = v),
            ),
            _row2(
              _t('SN', m.generatorSn, (v) => m.generatorSn = v),
              _t('KVA', m.kva, (v) => m.kva = v),
            ),
            _row3(
              _t('KW', m.kw, (v) => m.kw = v),
              _t('Volts', m.volts, (v) => m.volts = v),
              _t('Amps', m.amps, (v) => m.amps = v),
            ),
            _row3(
              _t('Phase', m.phase, (v) => m.phase = v),
              _t('Cycles', m.cycles, (v) => m.cycles = v),
              _t('RPM', m.rpm, (v) => m.rpm = v),
            ),
            const Divider(),
            _row3(
              _t('Control Mfr.', m.controlMfr,
                      (v) => m.controlMfr = v),
              _t('Model', m.controlModel,
                      (v) => m.controlModel = v),
              _t('SN', m.controlSn, (v) => m.controlSn = v),
            ),
            _row3(
              _t('Governor Mfr.', m.governorMfr,
                      (v) => m.governorMfr = v),
              _t('Model', m.governorModel,
                      (v) => m.governorModel = v),
              _t('SN', m.governorSn, (v) => m.governorSn = v),
            ),
            _row3(
              _t('Regulator Mfr.', m.regulatorMfr,
                      (v) => m.regulatorMfr = v),
              _t('Model', m.regulatorModel,
                      (v) => m.regulatorModel = v),
              _t('SN', m.regulatorSn, (v) => m.regulatorSn = v),
            ),
            const Divider(),
            const Text(
              'Fuel Monitoring',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            _row3(
              _t('Volume (gal)', m.volumeGal,
                      (v) => m.volumeGal = v),
              _t('Ullage (gal)', m.ullageGal,
                      (v) => m.ullageGal = v),
              _t('90% Ullage (gal)', m.ullage90Gal,
                      (v) => m.ullage90Gal = v),
            ),
            _row3(
              _t('TC Volume (gal)', m.tcVolumeGal,
                      (v) => m.tcVolumeGal = v),
              _t('Height (gal)', m.heightGal,
                      (v) => m.heightGal = v),
              _t('Water (gal)', m.waterGal,
                      (v) => m.waterGal = v),
            ),
            _row3(
              _t('Water (inches)', m.waterInches,
                      (v) => m.waterInches = v),
              _t('Temp (°F)', m.tempF, (v) => m.tempF = v),
              _t('Time', m.time, (v) => m.time = v),
            ),
            const Divider(),
            _t('Comments', m.comments, (v) => m.comments = v,
                maxLines: 3),
            _t('Deficiencies', m.deficiencies,
                    (v) => m.deficiencies = v,
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _intervalsCard(List<TestIntervalRecord> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Test Reading Intervals',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    final idx = rows.length;
                    final rec = TestIntervalRecord(
                      id: const Uuid().v4(),
                      inspectionId: widget.inspectionId,
                      index: idx,
                    );
                    await HiveBoxes.testIntervals.put(rec.id, rec);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Interval'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Target kW')),
                  DataColumn(label: Text('RPM')),
                  DataColumn(label: Text('Hz')),
                  DataColumn(label: Text('Eng. Water °F')),
                  DataColumn(label: Text('Rad. Water °F')),
                  DataColumn(label: Text('Oil Temp °F')),
                  DataColumn(label: Text('Oil PSI')),
                  DataColumn(label: Text('Panel V')),
                  DataColumn(label: Text('Measured V')),
                  DataColumn(label: Text('Panel A')),
                  DataColumn(label: Text('Measured A')),
                  DataColumn(label: Text('Panel kW')),
                  DataColumn(label: Text('Measured kW')),
                  DataColumn(label: Text('Battery V')),
                  DataColumn(label: Text('Fuel PSI')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text('${r.index + 1}')),
                        DataCell(
                          Text(r.realtimeKwTarget),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.engineRpm),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.frequencyHz),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.engineWaterF),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.radiatorWaterF),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.engineOilTempF),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.engineOilPsi),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.panelVolt),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.measuredVolt),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.panelAmp),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.measuredAmp),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.panelKw),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.measuredKw),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.batteryVolt),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Text(r.fuelPressure),
                          onTap: () => _editInterval(r),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editInterval(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await HiveBoxes.testIntervals
                                      .delete(r.id);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child:
                Text('No intervals yet. Add an interval to begin.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNameplate() async {
    final curr = _np!;
    await HiveBoxes.nameplates.put(curr.id, curr);
  }

  Future<void> _editInterval(TestIntervalRecord rec) async {
    final edited = await showDialog<TestIntervalRecord>(
      context: context,
      builder: (ctx) => _IntervalEditor(initial: rec),
    );
    if (edited != null) {
      await edited.save();
      if (mounted) setState(() {});
    }
  }

  Widget _row2(Widget a, Widget b) =>
      Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);

  Widget _row3(Widget a, Widget b, Widget c) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
      const SizedBox(width: 8),
      Expanded(child: c),
    ],
  );

  Widget _t(
      String label,
      String v,
      ValueChanged<String> on, {
        int maxLines = 1,
      }) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      initialValue: v,
      maxLines: maxLines,
      onChanged: on,
    );
  }
}

class _IntervalEditor extends StatefulWidget {
  final TestIntervalRecord initial;
  const _IntervalEditor({required this.initial});

  @override
  State<_IntervalEditor> createState() => _IntervalEditorState();
}

class _IntervalEditorState extends State<_IntervalEditor> {
  late TestIntervalRecord m;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    m = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Interval ${m.index + 1}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row2(
                _t('Target kW', m.realtimeKwTarget,
                        (v) => m.realtimeKwTarget = v),
                _t('RPM', m.engineRpm, (v) => m.engineRpm = v),
              ),
              const SizedBox(height: 8),
              _row2(
                _t('Hz', m.frequencyHz,
                        (v) => m.frequencyHz = v),
                _t('Battery V', m.batteryVolt,
                        (v) => m.batteryVolt = v),
              ),
              const SizedBox(height: 8),
              _row3(
                _t('Eng. Water °F', m.engineWaterF,
                        (v) => m.engineWaterF = v),
                _t('Rad. Water °F', m.radiatorWaterF,
                        (v) => m.radiatorWaterF = v),
                _t('Oil Temp °F', m.engineOilTempF,
                        (v) => m.engineOilTempF = v),
              ),
              const SizedBox(height: 8),
              _row2(
                _t('Oil PSI', m.engineOilPsi,
                        (v) => m.engineOilPsi = v),
                _t('Fuel PSI', m.fuelPressure,
                        (v) => m.fuelPressure = v),
              ),
              const Divider(),
              _row2(
                _t('Panel V', m.panelVolt,
                        (v) => m.panelVolt = v),
                _t('Measured V', m.measuredVolt,
                        (v) => m.measuredVolt = v),
              ),
              const SizedBox(height: 8),
              _row2(
                _t('Panel A', m.panelAmp,
                        (v) => m.panelAmp = v),
                _t('Measured A', m.measuredAmp,
                        (v) => m.measuredAmp = v),
              ),
              const SizedBox(height: 8),
              _row2(
                _t('Panel kW', m.panelKw,
                        (v) => m.panelKw = v),
                _t('Measured kW', m.measuredKw,
                        (v) => m.measuredKw = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, m),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _row2(Widget a, Widget b) =>
      Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);

  Widget _row3(Widget a, Widget b, Widget c) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
      const SizedBox(width: 8),
      Expanded(child: c),
    ],
  );

  Widget _t(
      String label,
      String v,
      ValueChanged<String> on,
      ) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      initialValue: v,
      onChanged: on,
    );
  }
}
