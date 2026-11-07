import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/catalog_part.dart';
import '../../domain/vendor.dart';
import '../../infra/pricing_repository.dart';

void _refreshPricing(WidgetRef ref) {
  ref.invalidate(vendorsProvider);
  ref.invalidate(allPricesProvider);
  ref.invalidate(partPricesProvider);
}

// ---------------------------------------------------------------- vendor

/// Add a vendor (when [vendor] is null) or edit one. Admin only.
Future<void> showVendorEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  Vendor? vendor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _VendorEditor(vendor: vendor, ref: ref),
  );
}

class _VendorEditor extends StatefulWidget {
  const _VendorEditor({required this.vendor, required this.ref});
  final Vendor? vendor;
  final WidgetRef ref;

  @override
  State<_VendorEditor> createState() => _VendorEditorState();
}

class _VendorEditorState extends State<_VendorEditor> {
  late final _name = TextEditingController(text: widget.vendor?.name);
  late final _contact = TextEditingController(text: widget.vendor?.contact);
  late final _phone = TextEditingController(text: widget.vendor?.phone);
  late final _email = TextEditingController(text: widget.vendor?.email);
  late final _account = TextEditingController(text: widget.vendor?.accountNumber);
  late final _notes = TextEditingController(text: widget.vendor?.notes);
  late bool _active = widget.vendor?.isActive ?? true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _contact, _phone, _email, _account, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (vendorKey(_name.text).isEmpty) {
      setState(() => _error = 'Enter the vendor name.');
      return;
    }
    final repo = widget.ref.read(pricingRepositoryProvider);
    final existing = widget.vendor;
    final base = existing ?? repo.newVendor(name: _name.text);
    final next = base.copyWith(
      name: _name.text,
      contact: _contact.text,
      phone: _phone.text,
      email: _email.text,
      accountNumber: _account.text,
      notes: _notes.text,
      isActive: _active,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await repo.saveVendor(next);
      _refreshPricing(widget.ref);
      AppSnackBar.successOn(messenger, existing == null ? 'Vendor added' : 'Vendor saved');
      nav.pop();
    } on DuplicateVendorException catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.existing.name} is already in the list.';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the vendor. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.vendor == null ? 'Add vendor' : 'Edit vendor',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('vendor_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Vendor name *'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _contact,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Contact person'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _account,
              decoration: const InputDecoration(labelText: 'Our account number'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive vendors are hidden when adding prices'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton(
              key: const Key('vendor_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- price

/// Record what a vendor charged (or quoted) for [part]. Admin only.
Future<void> showPriceSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogPart part,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PriceSheet(part: part, ref: ref),
  );
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.part, required this.ref});
  final CatalogPart part;
  final WidgetRef ref;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  final _amount = TextEditingController();
  final _vpn = TextEditingController();
  final _note = TextEditingController();
  List<Vendor>? _vendors;
  String? _vendorId;
  PriceKind _kind = PriceKind.paid;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.ref.read(pricingRepositoryProvider).vendors().then((v) {
      if (!mounted) return;
      final active = v.where((x) => x.isActive).toList();
      setState(() {
        _vendors = active;
        if (active.length == 1) _vendorId = active.first.id;
      });
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _vpn.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final cents = parseCents(_amount.text);
    if (_vendorId == null) {
      setState(() => _error = 'Choose the vendor.');
      return;
    }
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter the price for one, such as 24.50.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(pricingRepositoryProvider).addPrice(
            partId: widget.part.id,
            vendorId: _vendorId!,
            unitCents: cents,
            kind: _kind,
            vendorPartNumber: _vpn.text,
            pricedAt: _date,
            note: _note.text,
          );
      _refreshPricing(widget.ref);
      AppSnackBar.successOn(messenger, 'Price saved');
      nav.pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the price. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendors = _vendors;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add price', style: theme.textTheme.titleLarge),
            Text('${widget.part.partNumber} · ${widget.part.title}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            if (vendors == null)
              const LinearProgressIndicator()
            else if (vendors.isEmpty)
              const Text('Add a vendor first (Inventory → Vendors), then come '
                  'back to record prices.')
            else
              DropdownButtonFormField<String>(
                key: const Key('price_vendor'),
                initialValue: _vendorId,
                decoration: const InputDecoration(labelText: 'Vendor *'),
                items: [
                  for (final v in vendors)
                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                onChanged: (v) => setState(() => _vendorId = v),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('price_amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,$]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Price for one *',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<PriceKind>(
              showSelectedIcon: false,
              segments: [
                for (final k in PriceKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('price_vendor_pn'),
                  controller: _vpn,
                  decoration: const InputDecoration(labelText: "Vendor's part number"),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('MMM d, y').format(_date)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note',
                helperText: 'Invoice or PO number, quantity break, etc.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('price_save'),
              onPressed: _saving || (vendors?.isEmpty ?? true) ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save price'),
            ),
          ],
        ),
      ),
    );
  }
}
