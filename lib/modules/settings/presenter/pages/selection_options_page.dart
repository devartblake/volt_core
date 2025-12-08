import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/responsive_scaffold.dart';
import '../controllers/selection_options_provider.dart';

class SelectionOptionsPage extends ConsumerWidget {
  const SelectionOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(selectionOptionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canPop = GoRouter.of(context).canPop();

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Selection Options'),
        centerTitle: false,
        elevation: 0,
        leading: canPop
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context: context,
            colorScheme: colorScheme,
            title: 'Technicians',
            subtitle: 'Manage available technicians',
            icon: Icons.person_outline,
            items: svc.techs,
            onAdd: (v) => svc.addTech(v),
            onRemoveAt: (i) => svc.removeTechAt(i),
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            colorScheme: colorScheme,
            title: 'Generator Makes',
            subtitle: 'Manage generator manufacturers',
            icon: Icons.build_outlined,
            items: svc.makes,
            onAdd: (v) => svc.addMake(v),
            onRemoveAt: (i) => svc.removeMakeAt(i),
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            colorScheme: colorScheme,
            title: 'Voltage Ratings',
            subtitle: 'Manage voltage specifications',
            icon: Icons.electrical_services_outlined,
            items: svc.voltages,
            onAdd: (v) => svc.addVoltage(v),
            onRemoveAt: (i) => svc.removeVoltageAt(i),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> items,
    required Future<void> Function(String) onAdd,
    required Future<void> Function(int) onRemoveAt,
  }) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Input field
            Form(
              key: formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Add new item',
                        hintText: 'Enter value',
                        prefixIcon: const Icon(Icons.add_circle_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a value';
                        }
                        if (items.contains(value.trim())) {
                          return 'This item already exists';
                        }
                        return null;
                      },
                      onFieldSubmitted: (value) async {
                        if (formKey.currentState?.validate() ?? false) {
                          await onAdd(value.trim());
                          controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        await onAdd(controller.text.trim());
                        controller.clear();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items list
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No items added yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < items.length; i++)
                    Chip(
                      label: Text(
                        items[i],
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 18,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      onDeleted: () async {
                        await onRemoveAt(i);
                      },
                      backgroundColor: colorScheme.secondaryContainer,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      deleteButtonTooltipMessage: 'Remove ${items[i]}',
                    ),
                ],
              ),

            // Item count
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}