import 'package:flutter/material.dart';

import '../../../core/services/pdf/pdf_prefs_service.dart';

/// Picks which inspection PDF layout is produced: the standard print-ready one
/// or the classic (original) five-page one. Stored per device.
class PdfInspectionTemplateTile extends StatefulWidget {
  const PdfInspectionTemplateTile({super.key});

  @override
  State<PdfInspectionTemplateTile> createState() =>
      _PdfInspectionTemplateTileState();
}

class _PdfInspectionTemplateTileState extends State<PdfInspectionTemplateTile> {
  InspectionPdfStyle _style = InspectionPdfStyle.standard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    InspectionPdfStyle value;
    try {
      value = await PdfPrefsService.instance.getInspectionStyle();
    } catch (_) {
      value = InspectionPdfStyle.standard;
    }
    if (!mounted) return;
    setState(() {
      _style = value;
      _loading = false;
    });
  }

  Future<void> _change(InspectionPdfStyle value) async {
    setState(() => _style = value);
    await PdfPrefsService.instance.setInspectionStyle(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Inspection PDF template'),
      subtitle: Text(
        _style == InspectionPdfStyle.standard
            ? 'Standard: print-ready, pages flow when content is long.'
            : 'Classic: the original fixed five-page layout.',
      ),
      trailing: DropdownButton<InspectionPdfStyle>(
        value: _style,
        onChanged: _loading ? null : (v) => v == null ? null : _change(v),
        items: const [
          DropdownMenuItem(
            value: InspectionPdfStyle.standard,
            child: Text('Standard'),
          ),
          DropdownMenuItem(
            value: InspectionPdfStyle.classic,
            child: Text('Classic'),
          ),
        ],
      ),
    );
  }
}
