import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import '../../data/models/inspection.dart';

class SectionSignatures extends StatefulWidget {
  final Inspection model;
  final ValueChanged<Inspection> onChanged;
  const SectionSignatures({super.key, required this.model, required this.onChanged});

  @override
  State<SectionSignatures> createState() => _SectionSignaturesState();
}

class _SectionSignaturesState extends State<SectionSignatures> {
  final techCtl = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );
  final custCtl = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );
  final custNameCtl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    techCtl.dispose();
    custCtl.dispose();
    custNameCtl.dispose();
    super.dispose();
  }

  Future<String> _savePng(Uint8List bytes, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
      '${dir.path}/$name-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  Future<void> _handleSave() async {
    if (techCtl.isEmpty || custCtl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Please provide both signatures')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final techBytes = await techCtl.toPngBytes();
      final custBytes = await custCtl.toPngBytes();

      if (techBytes != null) {
        widget.model.technicianSignaturePath = await _savePng(techBytes, 'tech-sign');
      }
      if (custBytes != null) {
        widget.model.customerSignaturePath = await _savePng(custBytes, 'cust-sign');
      }

      widget.onChanged(widget.model);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Signatures saved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error saving signatures: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.draw_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signatures',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: custNameCtl,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSaved: (_) {
                widget.model.customerName = custNameCtl.text.trim();
              },
            ),
            const SizedBox(height: 24),
            _modernSignaturePad(
              'Technician Signature',
              Icons.engineering,
              techCtl,
              theme,
            ),
            const SizedBox(height: 20),
            _modernSignaturePad(
              'Customer Signature',
              Icons.person,
              custCtl,
              theme,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () {
                      techCtl.clear();
                      custCtl.clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Saving...' : 'Save Signatures'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernSignaturePad(
      String label,
      IconData icon,
      SignatureController controller,
      ThemeData theme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => controller.clear(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gesture,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sign here',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}