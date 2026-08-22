import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/equipment_providers.dart';
import '../../../customers/customer_site_repository.dart';
import '../../domain/entities/equipment_entity.dart';
import '../../infra/repositories/equipment_repository_impl.dart';

/// Reassigns a manually registered asset without changing its stable identity.
class AssetSiteAssignmentSheet extends ConsumerStatefulWidget {
  const AssetSiteAssignmentSheet({super.key, required this.asset});

  final EquipmentEntity asset;

  @override
  ConsumerState<AssetSiteAssignmentSheet> createState() => _AssetSiteAssignmentSheetState();
}

class _AssetSiteAssignmentSheetState extends ConsumerState<AssetSiteAssignmentSheet> {
  String? _siteId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _siteId = widget.asset.siteId;
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(customerSiteDirectoryProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: directory.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load sites: $error')),
          data: (data) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign service site', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(widget.asset.name, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                value: _siteId,
                decoration: const InputDecoration(labelText: 'Customer / service site'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No site selected')),
                  ...data.sites.where((site) => site.isActive).map(
                    (site) => DropdownMenuItem<String?>(
                      value: site.id,
                      child: Text('${data.customerNameFor(site.customerId)} — ${site.siteCode.isEmpty ? site.address : site.siteCode}'),
                    ),
                  ),
                ],
                onChanged: _saving ? null : (value) => setState(() => _siteId = value),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(data),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save assignment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(CustomerSiteDirectory directory) async {
    SiteRecord? site;
    for (final candidate in directory.sites) {
      if (candidate.id == _siteId) {
        site = candidate;
        break;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(equipmentRepositoryProvider).updateManualAssetSite(
            asset: widget.asset,
            siteId: _siteId,
            siteCode: site?.siteCode ?? '',
            location: site?.address ?? widget.asset.location,
          );
      ref.invalidate(equipmentListProvider);
      ref.invalidate(equipmentFacetsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update asset: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
