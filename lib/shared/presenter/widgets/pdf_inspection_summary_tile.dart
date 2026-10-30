import 'package:flutter/material.dart';

import '../../../core/services/pdf/pdf_prefs_service.dart';

/// Switch for the optional closing "Inspection Summary" page on inspection
/// PDFs. Off by default; the choice is stored per device.
class PdfInspectionSummaryTile extends StatefulWidget {
  const PdfInspectionSummaryTile({super.key});

  @override
  State<PdfInspectionSummaryTile> createState() =>
      _PdfInspectionSummaryTileState();
}

class _PdfInspectionSummaryTileState extends State<PdfInspectionSummaryTile> {
  bool _loading = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool value;
    try {
      value = await PdfPrefsService.instance.getIncludeInspectionSummary();
    } catch (_) {
      value = false;
    }
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    await PdfPrefsService.instance.setIncludeInspectionSummary(value);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Inspection summary page'),
      subtitle: const Text(
        'Add a closing page to inspection PDFs listing what passed and what '
        'needs attention.',
      ),
      value: _enabled,
      onChanged: _loading ? null : _onChanged,
    );
  }
}
