import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/equipment_providers.dart';
import '../../../customers/customer_site_repository.dart';
import '../../domain/entities/equipment_entity.dart';
import '../../infra/repositories/equipment_repository_impl.dart';

/// Registers a generic asset before any inspection exists for it.
///
/// This is deliberately a small common form. Type-specific fields belong in a
/// future template pack rather than becoming a new hard-coded form per asset.
class AssetRegistrationSheet extends ConsumerStatefulWidget {
  const AssetRegistrationSheet({super.key});

  @override
  ConsumerState<AssetRegistrationSheet> createState() =>
      _AssetRegistrationSheetState();
}

class _AssetRegistrationSheetState
    extends ConsumerState<AssetRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _voltage = TextEditingController();
  final _location = TextEditingController();
  final _siteCode = TextEditingController();
  final _notes = TextEditingController();
  AssetType _assetType = AssetType.generator;
  String? _siteId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _make.dispose();
    _model.dispose();
    _serial.dispose();
    _voltage.dispose();
    _location.dispose();
    _siteCode.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(equipmentRepositoryProvider)
          .registerAsset(
            name: _name.text,
            assetType: _assetType,
            make: _make.text,
            model: _model.text,
            serialNumber: _serial.text,
            voltage: _voltage.text,
            location: _location.text,
            siteCode: _siteCode.text,
            siteId: _siteId,
            notes: _notes.text,
          );
      ref.invalidate(equipmentListProvider);
      ref.invalidate(equipmentFacetsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset saved and queued for sync.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not register asset: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final directory = ref.watch(customerSiteDirectoryProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register asset',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Register a physical asset now; inspection history can be added later.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _field(_name, 'Asset name', required: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<AssetType>(
                  initialValue: _assetType,
                  decoration: const InputDecoration(labelText: 'Asset type'),
                  items: AssetType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_assetTypeLabel(type)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _assetType = value!),
                ),
                const SizedBox(height: 12),
                directory.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(
                    'Customer/site directory unavailable. You can still register without a selected site.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  data: (data) => DropdownButtonFormField<String?>(
                    initialValue: _siteId,
                    decoration: const InputDecoration(
                      labelText: 'Customer / service site',
                      helperText: 'Optional — links this asset to the selected service site.',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No site selected'),
                      ),
                      ...data.sites.where((site) => site.isActive).map(
                        (site) => DropdownMenuItem<String?>(
                          value: site.id,
                          child: Text(
                            '${data.customerNameFor(site.customerId)} — ${site.siteCode.isEmpty ? site.address : site.siteCode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (siteId) {
                            SiteRecord? selected;
                            for (final site in data.sites) {
                              if (site.id == siteId) {
                                selected = site;
                                break;
                              }
                            }
                            setState(() {
                              _siteId = siteId;
                              if (selected != null) {
                                _siteCode.text = selected.siteCode;
                                _location.text = selected.address;
                              }
                            });
                          },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_make, 'Make')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_model, 'Model')),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_serial, 'Serial number'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_voltage, 'Voltage')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_siteCode, 'Site code')),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_location, 'Location / address'),
                const SizedBox(height: 12),
                _field(_notes, 'Notes', maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_business_outlined),
                    label: Text(_saving ? 'Saving…' : 'Register asset'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? '$label is required.'
              : null
        : null,
  );

  static String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.transferSwitch:
        return 'Transfer switch';
      case AssetType.emergencyLighting:
        return 'Emergency lighting';
      case AssetType.evCharger:
        return 'EV charger';
      case AssetType.batteryEnergyStorage:
        return 'Battery energy storage';
      default:
        return type.name[0].toUpperCase() + type.name.substring(1);
    }
  }
}
