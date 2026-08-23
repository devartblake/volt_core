import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../schedule/presenter/controllers/schedule_controller.dart';
import '../../domain/entities/work_order_entity.dart';
import '../work_order_providers.dart';

class WorkOrderListPage extends ConsumerStatefulWidget {
  const WorkOrderListPage({super.key});

  @override
  ConsumerState<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends ConsumerState<WorkOrderListPage> {
  final _search = TextEditingController();
  WorkOrderStatus? _status;
  WorkOrderPriority? _priority;
  DateTimeRange? _dueRange;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WorkOrderEntity> _filtered(List<WorkOrderEntity> source) {
    final query = _search.text.trim().toLowerCase();
    return source.where((order) {
      if (_status != null && order.status != _status) return false;
      if (_priority != null && order.priority != _priority) return false;
      if (_dueRange != null) {
        final date = order.scheduledFor;
        if (date == null || date.isBefore(_dueRange!.start) || date.isAfter(_dueRange!.end.add(const Duration(days: 1)))) return false;
      }
      if (query.isEmpty) return true;
      return [
        order.title,
        order.description,
        order.customerId ?? '',
        order.siteId ?? '',
        order.assetId ?? '',
        order.assignedToUserId ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(workOrderListProvider);
    final scheduledTaskCount = ref.watch(scheduleControllerProvider).maybeWhen(
          data: (tasks) => tasks
              .where((task) => task.status == 'scheduled' || task.status == 'pending')
              .length,
          orElse: () => 0,
        );
    return AppPage(
      title: 'All Jobs',
      fab: FloatingActionButton.extended(
        onPressed: () => context.goNamed(RouteNames.workOrderNew),
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Create job'),
      ),
      body: orders.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => EmptyState.error(
          message: '$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(workOrderListProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) {
          final visible = _filtered(all);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(workOrderListProvider.future).then<void>((_) {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Search jobs',
                    hintText: 'Title, notes, customer, site, asset, or assignee',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EnumFilter<WorkOrderStatus>(
                      label: 'Status',
                      value: _status,
                      values: WorkOrderStatus.values,
                      labelFor: _statusLabel,
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    _EnumFilter<WorkOrderPriority>(
                      label: 'Priority',
                      value: _priority,
                      values: WorkOrderPriority.values,
                      labelFor: priorityLabel,
                      onChanged: (value) => setState(() => _priority = value),
                    ),
                    FilterChip(
                      selected: _dueRange != null,
                      label: Text(_dueRange == null ? 'Due date' : 'Due date filtered'),
                      onSelected: (_) => _pickRange(),
                      onDeleted: _dueRange == null ? null : () => setState(() => _dueRange = null),
                    ),
                    if (_status != null || _priority != null || _dueRange != null)
                      TextButton(
                        onPressed: () => setState(() { _status = null; _priority = null; _dueRange = null; }),
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.work_outline,
                    title: all.isEmpty ? 'No jobs yet' : 'No jobs match these filters',
                    message: all.isEmpty
                        ? scheduledTaskCount == 0
                            ? 'Work orders are created from Create Job or an inspection maintenance handoff.'
                            : 'Scheduled tasks are shown on Schedule until they become work orders. You have $scheduledTaskCount scheduled task${scheduledTaskCount == 1 ? '' : 's'}.'
                        : 'Adjust or clear a filter to see more jobs.',
                    action: all.isEmpty
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () => context.goNamed(RouteNames.workOrderNew),
                                icon: const Icon(Icons.add),
                                label: const Text('Create job'),
                              ),
                              if (scheduledTaskCount > 0)
                                OutlinedButton.icon(
                                  onPressed: () => context.goNamed(RouteNames.schedule),
                                  icon: const Icon(Icons.calendar_month_outlined),
                                  label: const Text('View schedule'),
                                ),
                            ],
                          )
                        : null,
                  )
                else
                  ...visible.map((order) => _WorkOrderCard(order: order)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dueRange,
    );
    if (result != null && mounted) setState(() => _dueRange = result);
  }
}

class _EnumFilter<T> extends StatelessWidget {
  const _EnumFilter({required this.label, required this.value, required this.values, required this.labelFor, required this.onChanged});
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<T?>(
      value: value,
      hint: Text(label),
      items: [DropdownMenuItem<T?>(value: null, child: Text('Any $label')), ...values.map((item) => DropdownMenuItem<T?>(value: item, child: Text(labelFor(item))))],
      onChanged: onChanged,
    ),
  );
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.order});
  final WorkOrderEntity order;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(_statusIcon(order.status))),
      title: Text(order.title),
      subtitle: Text('${priorityLabel(order.priority)} priority • ${_statusLabel(order.status)}${order.scheduledFor == null ? '' : ' • ${_dateLabel(order.scheduledFor!)}'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.goNamed(RouteNames.workOrderEdit, pathParameters: {'id': order.id}),
    ),
  );
}

String _statusLabel(WorkOrderStatus value) => switch (value) { WorkOrderStatus.draft => 'Draft', WorkOrderStatus.scheduled => 'Scheduled', WorkOrderStatus.inProgress => 'In progress', WorkOrderStatus.completed => 'Completed', WorkOrderStatus.cancelled => 'Cancelled' };
String priorityLabel(WorkOrderPriority value) => switch (value) { WorkOrderPriority.low => 'Low', WorkOrderPriority.normal => 'Normal', WorkOrderPriority.high => 'High', WorkOrderPriority.urgent => 'Urgent' };
IconData _statusIcon(WorkOrderStatus value) => switch (value) { WorkOrderStatus.draft => Icons.edit_note_outlined, WorkOrderStatus.scheduled => Icons.event_outlined, WorkOrderStatus.inProgress => Icons.play_circle_outline, WorkOrderStatus.completed => Icons.task_alt_outlined, WorkOrderStatus.cancelled => Icons.cancel_outlined };
String _dateLabel(DateTime value) => '${value.month}/${value.day}/${value.year}';
