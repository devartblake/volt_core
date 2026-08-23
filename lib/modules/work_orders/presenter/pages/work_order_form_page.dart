import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../customers/customer_site_repository.dart';
import '../../domain/entities/work_order_entity.dart';
import '../../infra/repositories/work_order_repository_impl.dart';
import '../work_order_providers.dart';
import 'work_order_list_page.dart' show priorityLabel;

class WorkOrderFormPage extends ConsumerStatefulWidget {
  const WorkOrderFormPage({super.key, this.id});
  final String? id;
  @override
  ConsumerState<WorkOrderFormPage> createState() => _WorkOrderFormPageState();
}

class _WorkOrderFormPageState extends ConsumerState<WorkOrderFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  WorkOrderPriority _priority = WorkOrderPriority.normal;
  String? _customerId;
  String? _siteId;
  String? _assetId;
  DateTime? _scheduledFor;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  void _load(WorkOrderEntity order) {
    if (_initialized) return;
    _initialized = true;
    _title.text = order.title;
    _description.text = order.description;
    _priority = order.priority;
    _customerId = order.customerId;
    _siteId = order.siteId;
    _assetId = order.assetId;
    _scheduledFor = order.scheduledFor;
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.id == null ? null : ref.watch(workOrderProvider(widget.id!));
    if (existing != null) {
      return existing.when(
        loading: () => const AppPage(title: 'Edit job', body: LoadingIndicator()),
        error: (error, _) => AppPage(title: 'Edit job', body: EmptyState.error(message: '$error')),
        data: (order) {
          if (order == null) return const AppPage(title: 'Edit job', body: EmptyState(icon: Icons.work_off_outlined, title: 'Job not found'));
          _load(order);
          return _page(context, order);
        },
      );
    }
    return _page(context, null);
  }

  Widget _page(BuildContext context, WorkOrderEntity? existing) {
    final directory = ref.watch(customerSiteDirectoryProvider);
    final equipment = ref.watch(equipmentListProvider);
    return AppPage(
      title: existing == null ? 'Create job' : 'Edit job',
      leading: IconButton(
        tooltip: 'Back',
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Job title'),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value == null || value.trim().isEmpty ? 'A job title is required.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WorkOrderPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: WorkOrderPriority.values.map((value) => DropdownMenuItem(value: value, child: Text(priorityLabel(value)))).toList(),
              onChanged: (value) => setState(() => _priority = value ?? WorkOrderPriority.normal),
            ),
            const SizedBox(height: 16),
            _DirectorySelectors(
              directory: directory,
              equipment: equipment,
              customerId: _customerId,
              siteId: _siteId,
              assetId: _assetId,
              onCustomerChanged: (value) => setState(() { _customerId = value; _siteId = null; _assetId = null; }),
              onSiteChanged: (value) => setState(() { _siteId = value; _assetId = null; }),
              onAssetChanged: (value) => setState(() => _assetId = value),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scheduled for'),
              subtitle: Text(_scheduledFor == null ? 'Not scheduled — job remains a draft.' : '${_scheduledFor!.month}/${_scheduledFor!.day}/${_scheduledFor!.year}'),
              trailing: Wrap(spacing: 4, children: [
                if (_scheduledFor != null) IconButton(tooltip: 'Clear date', onPressed: () => setState(() => _scheduledFor = null), icon: const Icon(Icons.clear)),
                IconButton(tooltip: 'Select date', onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined)),
              ]),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Service scope / notes'),
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(existing),
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save job'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(context: context, initialDate: _scheduledFor ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
    if (selected != null && mounted) setState(() => _scheduledFor = selected);
  }

  Future<void> _save(WorkOrderEntity? existing) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      if (existing == null) {
        await repo.create(title: _title.text, priority: _priority, customerId: _customerId, siteId: _siteId, assetId: _assetId, scheduledFor: _scheduledFor, description: _description.text);
      } else {
        await repo.save(existing.copyWith(
          title: _title.text.trim(), priority: _priority,
          customerId: _customerId, clearCustomerId: _customerId == null,
          siteId: _siteId, clearSiteId: _siteId == null,
          assetId: _assetId, clearAssetId: _assetId == null,
          scheduledFor: _scheduledFor, clearScheduledFor: _scheduledFor == null,
          description: _description.text.trim(),
        ));
      }
      ref.invalidate(workOrderListProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save job: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
}

class _DirectorySelectors extends StatelessWidget {
  const _DirectorySelectors({required this.directory, required this.equipment, required this.customerId, required this.siteId, required this.assetId, required this.onCustomerChanged, required this.onSiteChanged, required this.onAssetChanged});
  final AsyncValue<CustomerSiteDirectory> directory;
  final AsyncValue<List<Equipment>> equipment;
  final String? customerId; final String? siteId; final String? assetId;
  final ValueChanged<String?> onCustomerChanged; final ValueChanged<String?> onSiteChanged; final ValueChanged<String?> onAssetChanged;
  @override
  Widget build(BuildContext context) {
    if (directory.isLoading || equipment.isLoading) return const Padding(padding: EdgeInsets.all(12), child: LoadingIndicator.inline());
    if (directory.hasError || equipment.hasError) return Text('Customer/site or asset directory is unavailable.', style: TextStyle(color: Theme.of(context).colorScheme.error));
    final data = directory.requireValue;
    final sites = data.sites.where((site) => customerId == null || site.customerId == customerId).toList();
    final assets = equipment.requireValue.where((asset) => siteId == null || asset.siteId == siteId).toList();
    return Column(children: [
      DropdownButtonFormField<String?>(
        key: ValueKey('customer-$customerId'), initialValue: customerId, decoration: const InputDecoration(labelText: 'Customer'),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('No customer selected')), ...data.customers.map((customer) => DropdownMenuItem<String?>(value: customer.id, child: Text(customer.name)))], onChanged: onCustomerChanged,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        key: ValueKey('site-$siteId'), initialValue: siteId, decoration: const InputDecoration(labelText: 'Service site'),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('No site selected')), ...sites.map((site) => DropdownMenuItem<String?>(value: site.id, child: Text(site.siteCode.isEmpty ? site.address : site.siteCode)))], onChanged: onSiteChanged,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        key: ValueKey('asset-$assetId'), initialValue: assetId, decoration: const InputDecoration(labelText: 'Asset'),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('No asset selected')), ...assets.map((asset) => DropdownMenuItem<String?>(value: asset.registryId ?? asset.id, child: Text(asset.name)))], onChanged: onAssetChanged,
      ),
    ]);
  }
}
