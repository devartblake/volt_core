import 'package:flutter/material.dart';
import '../../../core/services/pdf_prefs_service.dart';

/// A simple switch tile that lets the technician opt in/out of
/// automatically opening the system share/email sheet when PDFs
/// are generated.
///
/// Drop this into any settings screen's ListView / Column.
class PdfEmailOptInTile extends StatefulWidget {
  const PdfEmailOptInTile({super.key});

  @override
  State<PdfEmailOptInTile> createState() => _PdfEmailOptInTileState();
}

class _PdfEmailOptInTileState extends State<PdfEmailOptInTile> {
  bool _loading = true;
  bool _emailAllowed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await PdfPrefsService.instance.getEmailAllowed();
    if (!mounted) return;
    setState(() {
      _emailAllowed = value;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool newValue) async {
    setState(() {
      _emailAllowed = newValue;
    });
    await PdfPrefsService.instance.setEmailAllowed(newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Allow PDF email/share'),
        subtitle: Text('Loading current setting...'),
      );
    }

    return SwitchListTile(
      title: const Text('Allow PDF email/share'),
      subtitle: const Text(
        'If ON: after saving a PDF, the system share/email sheet will open.\n'
            'If OFF: PDFs are saved only to the app directory.',
      ),
      value: _emailAllowed,
      onChanged: _onChanged,
    );
  }
}
