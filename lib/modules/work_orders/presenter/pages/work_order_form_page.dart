import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../admin/domain/entities/technician_entity.dart';
import '../../../customers/customer_site_repository.dart';
import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_event.dart';
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
  String? _assignedToUserId;
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
    _assignedToUserId = order.assignedToUserId;
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
    final assignees = ref.watch(workOrderAssigneesProvider);
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
            _AssigneeSelector(
              assignees: assignees,
              assignedToUserId: _assignedToUserId,
              onChanged: (value) => setState(() => _assignedToUserId = value),
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
            if (existing != null) ...[
              const SizedBox(height: 24),
              _LifecycleActions(
                order: existing,
                onTransition: _transition,
              ),
              const SizedBox(height: 24),
              _AuditTimeline(orderId: existing.id),
            ],
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
        await repo.create(title: _title.text, priority: _priority, customerId: _customerId, siteId: _siteId, assetId: _assetId, assignedToUserId: _assignedToUserId, scheduledFor: _scheduledFor, description: _description.text);
      } else {
        await repo.save(existing.copyWith(
          title: _title.text.trim(), priority: _priority,
          customerId: _customerId, clearCustomerId: _customerId == null,
          siteId: _siteId, clearSiteId: _siteId == null,
          assetId: _assetId, clearAssetId: _assetId == null,
          assignedToUserId: _assignedToUserId,
          clearAssignedToUserId: _assignedToUserId == null,
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

  Future<void> _transition(WorkOrderEntity order, WorkOrderStatus next) async {
    if (next == WorkOrderStatus.scheduled && order.scheduledFor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a scheduled date before dispatching this job.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(workOrderRepositoryProvider).transition(order.id, next);
      ref.invalidate(workOrderProvider(order.id));
      ref.invalidate(workOrderListProvider);
      ref.invalidate(workOrderEventsProvider(order.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job marked ${_statusLabel(next)}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update job status: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

class _AssigneeSelector extends StatelessWidget {
  const _AssigneeSelector({
    required this.assignees,
    required this.assignedToUserId,
    required this.onChanged,
  });

  final AsyncValue<List<TechnicianEntity>> assignees;
  final String? assignedToUserId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return assignees.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LoadingIndicator.inline(),
      ),
      error: (_, __) => Text(
        'Technician roster is unavailable. You can assign this job later.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (users) => DropdownButtonFormField<String?>(
        key: ValueKey('assignee-$assignedToUserId'),
        initialValue: assignedToUserId,
        decoration: const InputDecoration(labelText: 'Assigned technician'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Unassigned'),
          ),
          ...users.map(
            (user) => DropdownMenuItem<String?>(
              value: user.id,
              child: Text(user.name),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({
    required this.order,
    required this.onTransition,
  });

  final WorkOrderEntity order;
  final Future<void> Function(WorkOrderEntity, WorkOrderStatus) onTransition;

  @override
  Widget build(BuildContext context) {
    final next = order.allowedNextStatuses.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Current: ${_statusLabel(order.status)}'),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in next)
                    FilledButton.tonalIcon(
                      onPressed: status == WorkOrderStatus.scheduled &&
                              order.scheduledFor == null
                          ? null
                          : () => onTransition(order, status),
                      icon: Icon(_statusIcon(status)),
                      label: Text(_transitionLabel(status)),
                    ),
                ],
              ),
              if (order.status == WorkOrderStatus.draft &&
                  order.scheduledFor == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Choose a scheduled date, save the job, then dispatch it.',
                  ),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('This job is closed and cannot be reopened.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditTimeline extends ConsumerWidget {
  const _AuditTimeline({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(workOrderEventsProvider(orderId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Recorded by the database after synchronization.'),
            const SizedBox(height: 12),
            events.when(
              loading: () => const LoadingIndicator.inline(),
              error: (_, __) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(workOrderEventsProvider(orderId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry activity history'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'No synchronized activity yet. Offline changes appear here after sync.',
                  );
                }
                return Column(
                  children: [
                    for (final event in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_eventIcon(event.type)),
                        title: Text(_eventLabel(event)),
                        subtitle: Text(_eventDateLabel(event.createdAt)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _eventLabel(WorkOrderEvent event) => switch (event.type) {
      WorkOrderEventType.created => 'Job created',
      WorkOrderEventType.statusChanged =>
        'Status changed from ${_statusName(event.fromStatus)} to ${_statusName(event.toStatus)}',
      WorkOrderEventType.assignmentChanged =>
        event.assignedToUserId == null
            ? 'Technician unassigned'
            : 'Technician assignment changed',
    };

String _statusName(String? value) {
  if (value == null || value.isEmpty) return 'unknown';
  return switch (value) {
    'inProgress' => 'In progress',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _eventDateLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} '
      '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
}

IconData _eventIcon(WorkOrderEventType type) => switch (type) {
      WorkOrderEventType.created => Icons.add_task_outlined,
      WorkOrderEventType.statusChanged => Icons.sync_alt_outlined,
      WorkOrderEventType.assignmentChanged => Icons.person_outline,
    };

String _statusLabel(WorkOrderStatus value) => switch (value) {
      WorkOrderStatus.draft => 'Draft',
      WorkOrderStatus.scheduled => 'Scheduled',
      WorkOrderStatus.inProgress => 'In progress',
      WorkOrderStatus.completed => 'Completed',
      WorkOrderStatus.cancelled => 'Cancelled',
    };

String _transitionLabel(WorkOrderStatus value) => switch (value) {
      WorkOrderStatus.scheduled => 'Dispatch',
      WorkOrderStatus.inProgress => 'Start work',
      WorkOrderStatus.completed => 'Complete',
      WorkOrderStatus.cancelled => 'Cancel job',
      WorkOrderStatus.draft => 'Draft',
    };

IconData _statusIcon(WorkOrderStatus value) => switch (value) {
      WorkOrderStatus.draft => Icons.edit_note_outlined,
      WorkOrderStatus.scheduled => Icons.event_available_outlined,
      WorkOrderStatus.inProgress => Icons.play_circle_outline,
      WorkOrderStatus.completed => Icons.task_alt_outlined,
      WorkOrderStatus.cancelled => Icons.cancel_outlined,
    };
