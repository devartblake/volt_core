import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../data/models/maintenance_record.dart';

class SectionMaintSignatures extends StatefulWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintSignatures({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<SectionMaintSignatures> createState() => _SectionMaintSignaturesState();
}

class _SectionMaintSignaturesState extends State<SectionMaintSignatures> {
  late final SignatureController _technicianController;
  late final SignatureController _customerController;

  @override
  void initState() {
    super.initState();

    _technicianController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _customerController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Load existing signatures if available
    // Note: You'll need to add signature data fields to MaintenanceRecord
    // For now, we'll just track if signatures exist
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _update(void Function() fn) {
    fn();
    widget.onChanged(widget.model);
  }

  Future<void> _pickDate(
      BuildContext context, {
        required DateTime? initial,
        required void Function(DateTime?) onSelected,
      }) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (result != null) {
      onSelected(result);
    }
  }

  Future<void> _saveTechnicianSignature() async {
    if (_technicianController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first')),
      );
      return;
    }

    final signature = await _technicianController.toPngBytes();
    if (signature != null) {
      // Here you would save the signature bytes to your model
      // For now, we'll just show a success message
      // You'll need to add a field like: model.technicianSignatureImage = signature;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Technician signature saved'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveCustomerSignature() async {
    if (_customerController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first')),
      );
      return;
    }

    final signature = await _customerController.toPngBytes();
    if (signature != null) {
      // Here you would save the signature bytes to your model
      // model.customerSignatureImage = signature;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Customer signature saved'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final techDate = widget.model.technicianSignatureDate;
    final custDate = widget.model.customerSignatureDate;

    String _fmtDate(DateTime? d) =>
        d == null ? '' : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.draw_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signatures',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Technician signature section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.engineering_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Technician Signature',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    initialValue: widget.model.technicianSignatureName,
                    onChanged: (v) =>
                        _update(() => widget.model.technicianSignatureName = v),
                  ),
                  const SizedBox(height: 12),

                  // Date field
                  GestureDetector(
                    onTap: () => _pickDate(
                      context,
                      initial: techDate,
                      onSelected: (d) => _update(() => widget.model.technicianSignatureDate = d),
                    ),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                          prefixIcon: const Icon(Icons.event),
                        ),
                        controller: TextEditingController(text: _fmtDate(techDate)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Signature pad label
                  Row(
                    children: [
                      Text(
                        'Draw Signature',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          _technicianController.clear();
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Signature pad
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Signature(
                        controller: _technicianController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save signature button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveTechnicianSignature,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Signature'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Customer signature section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 20,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Customer / Site Representative',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    initialValue: widget.model.customerSignatureName,
                    onChanged: (v) =>
                        _update(() => widget.model.customerSignatureName = v),
                  ),
                  const SizedBox(height: 12),

                  // Date field
                  GestureDetector(
                    onTap: () => _pickDate(
                      context,
                      initial: custDate,
                      onSelected: (d) => _update(() => widget.model.customerSignatureDate = d),
                    ),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                          prefixIcon: const Icon(Icons.event),
                        ),
                        controller: TextEditingController(text: _fmtDate(custDate)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Signature pad label
                  Row(
                    children: [
                      Text(
                        'Draw Signature',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          _customerController.clear();
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Signature pad
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Signature(
                        controller: _customerController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save signature button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveCustomerSignature,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Signature'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Signatures are captured digitally and will be included in the PDF export.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}