import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/tenants/tenants_service.dart';
import '../../../inspections/presenter/controllers/user_profile_controller.dart';

class TenantsSettingsPage extends ConsumerStatefulWidget {
  const TenantsSettingsPage({super.key});

  @override
  ConsumerState<TenantsSettingsPage> createState() =>
      _TenantsSettingsPageState();
}

class _TenantsSettingsPageState extends ConsumerState<TenantsSettingsPage> {
  final _tenantController = TextEditingController();

  @override
  void dispose() {
    _tenantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncService = ref.watch(tenantsServiceProvider);
    final currentTenant = ref.watch(currentTenantProvider);

    return asyncService.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Tenants')),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Tenants')),
        body: Center(
          child: Text('Failed to load tenants: $err'),
        ),
      ),
      data: (service) {
        final tenants = service.getTenants();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tenants'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Current tenant label
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current tenant: $currentTenant',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),

                // Add tenant row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tenantController,
                        decoration: const InputDecoration(
                          labelText: 'Add tenant',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        final name = _tenantController.text.trim();
                        if (name.isEmpty) return;

                        final updated = [...tenants, name];
                        await service.setTenants(updated);
                        // Also update the current tenant provider if desired
                        ref
                            .read(currentTenantProvider.notifier)
                            .switchTenant(name);

                        setState(() {
                          _tenantController.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: tenants.isEmpty
                      ? const Center(
                    child: Text(
                      'No tenants saved yet.\nAdd one using the field above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ListView.separated(
                    itemCount: tenants.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tenant = tenants[index];
                      final isCurrent = tenant == currentTenant;

                      return ListTile(
                        title: Text(tenant),
                        leading: isCurrent
                            ? const Icon(Icons.check_circle,
                            color: Colors.green)
                            : const Icon(Icons.circle_outlined),
                        subtitle: isCurrent
                            ? const Text('Current tenant')
                            : null,
                        onTap: () async {
                          ref
                              .read(currentTenantProvider.notifier)
                              .switchTenant(tenant);
                          await service.setCurrentTenant(tenant);
                          setState(() {});
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final updated = [...tenants]..removeAt(index);
                            await service.setTenants(updated);

                            // If we deleted the current tenant, reset to first or empty.
                            if (tenant == currentTenant) {
                              if (updated.isNotEmpty) {
                                final newCurrent = updated.first;
                                ref
                                    .read(
                                    currentTenantProvider.notifier)
                                    .switchTenant(newCurrent);
                                await service
                                    .setCurrentTenant(newCurrent);
                              } else {
                                // No tenants left; we just keep currentTenantProvider state,
                                // or you can set a default.
                              }
                            }

                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
