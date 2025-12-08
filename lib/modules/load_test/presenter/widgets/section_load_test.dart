import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../inspections/presenter/controllers/inspection_controller.dart';
import '../../infra/models/load_test_record.dart';

class SectionLoadTest extends ConsumerStatefulWidget {
  final String inspectionId;
  const SectionLoadTest({super.key, required this.inspectionId});

  @override
  ConsumerState<SectionLoadTest> createState() => _SectionLoadTestState();
}

class _SectionLoadTestState extends ConsumerState<SectionLoadTest> {
  @override
  Widget build(BuildContext context) {
    final ctl = ref.read(inspectionControllerProvider);
    final rows = ctl.listLoadTests(widget.inspectionId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Load Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
              onPressed: () async {
                await ctl.addLoadTestRow(widget.inspectionId, loadPercent: 0, minutes: 0);
                if (mounted) setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('% Load')),
                DataColumn(label: Text('Minutes')),
                DataColumn(label: Text('V L1-L2')),
                DataColumn(label: Text('V L2-L3')),
                DataColumn(label: Text('V L1-L3')),
                DataColumn(label: Text('Hz')),
                DataColumn(label: Text('Current (A)')),
                DataColumn(label: Text('kW')),
                DataColumn(label: Text('Pass')),
                DataColumn(label: Text('Notes')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('${r.stepIndex + 1}')),
                    DataCell(Text('${r.loadPercent}'), onTap: () => _editRow(r)),
                    DataCell(Text('${r.durationMinutes}'), onTap: () => _editRow(r)),
                    DataCell(Text(r.voltageL1L2), onTap: () => _editRow(r)),
                    DataCell(Text(r.voltageL2L3), onTap: () => _editRow(r)),
                    DataCell(Text(r.voltageL1L3), onTap: () => _editRow(r)),
                    DataCell(Text(r.frequencyHz), onTap: () => _editRow(r)),
                    DataCell(Text(r.currentA), onTap: () => _editRow(r)),
                    DataCell(Text(r.measuredKw), onTap: () => _editRow(r)),
                    DataCell(Icon(r.pass ? Icons.check_circle : Icons.cancel, color: r.pass ? Colors.green : Colors.red)),
                    DataCell(Text(r.notes, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _editRow(r)),
                    DataCell(Row(children: [
                      IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _editRow(r)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () async {
                          await ctl.deleteLoadTestRow(r.id);
                          if (mounted) setState(() {});
                        },
                      ),
                    ])),
                  ]),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No load-test steps yet. Tap "Add Step" to begin.'),
            ),
        ]),
      ),
    );
  }

  Future<void> _editRow(LoadTestRecord rec) async {
    final updated = await showDialog<LoadTestRecord>(
      context: context,
      builder: (ctx) => _LoadRowEditor(initial: rec),
    );
    if (updated != null) {
      final ctl = ref.read(inspectionControllerProvider);
      await ctl.updateLoadTestRow(updated);
      if (mounted) setState(() {});
    }
  }
}

class _LoadRowEditor extends StatefulWidget {
  final LoadTestRecord initial;
  const _LoadRowEditor({required this.initial});

  @override
  State<_LoadRowEditor> createState() => _LoadRowEditorState();
}

class _LoadRowEditorState extends State<_LoadRowEditor> {
  late LoadTestRecord m;
  final _formKey = GlobalKey<FormState>();
  final _percentOptions = const [0, 25, 50, 75, 100];

  @override
  void initState() {
    super.initState();
    m = widget.initial.copyWith(); // editable copy
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Step ${m.stepIndex + 1}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: '% Load'),
                  value: _percentOptions.contains(m.loadPercent) ? m.loadPercent : 0,
                  items: _percentOptions.map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                  onChanged: (v) => setState(() => m = m.copyWith(loadPercent: v ?? 0)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  initialValue: '${m.durationMinutes}',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => m = m.copyWith(durationMinutes: int.tryParse(v) ?? 0),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _t('V L1-L2', m.voltageL1L2, (v) => m = m.copyWith(voltageL1L2: v))),
              const SizedBox(width: 8),
              Expanded(child: _t('V L2-L3', m.voltageL2L3, (v) => m = m.copyWith(voltageL2L3: v))),
              const SizedBox(width: 8),
              Expanded(child: _t('V L1-L3', m.voltageL1L3, (v) => m = m.copyWith(voltageL1L3: v))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _t('Hz', m.frequencyHz, (v) => m = m.copyWith(frequencyHz: v))),
              const SizedBox(width: 8),
              Expanded(child: _t('Current (A)', m.currentA, (v) => m = m.copyWith(currentA: v))),
              const SizedBox(width: 8),
              Expanded(child: _t('Measured kW', m.measuredKw, (v) => m = m.copyWith(measuredKw: v))),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pass'),
              value: m.pass,
              onChanged: (v) => setState(() => m = m.copyWith(pass: v)),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
              initialValue: m.notes,
              onChanged: (v) => m = m.copyWith(notes: v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, m),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _t(String label, String value, ValueChanged<String> on) => TextFormField(
    decoration: InputDecoration(labelText: label),
    initialValue: value,
    onChanged: on,
  );
}
