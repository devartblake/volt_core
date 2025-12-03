import 'package:flutter/material.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Admin Configuration',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use this section for system-wide configuration: '
                'RBAC policies, template settings, infra retention windows, etc.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Enable advanced logging'),
            subtitle:
            const Text('Collect more detailed logs for troubleshooting.'),
            value: true,
            onChanged: (v) {
              // TODO: wire to settings service
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Data retention policy'),
            subtitle: const Text('Configure how long archives are kept.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: navigate to detailed setting page
            },
          ),
          ListTile(
            title: const Text('RBAC roles & permissions'),
            subtitle:
            const Text('Fine-tune technician, supervisor, and admin roles.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: navigate to RBAC management
            },
          ),
        ],
      ),
    );
  }
}
