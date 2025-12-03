import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/responsive_scaffold.dart';
import '../../../inspections/providers/user_profile_provider.dart';
import '../../../inspections/providers/app_badges_provider.dart';

/// Settings page for app configuration
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _autoSync = true;
  String _language = 'English';
  String _dateFormat = 'MM/DD/YYYY';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = ref.watch(appBadgesProvider);
    final userProfile = ref.watch(userProfileProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _SectionHeader(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme throughout the app'),
                value: _darkMode,
                onChanged: (value) {
                  setState(() => _darkMode = value);
                  // TODO: Implement theme switching
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Theme switching - Coming soon'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(_language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showLanguageDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Date Format'),
                subtitle: Text(_dateFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDateFormatDialog(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _SectionHeader(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive alerts for important updates'),
                value: _notifications,
                onChanged: (value) {
                  setState(() => _notifications = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Data & Sync Section
          _SectionHeader(
            icon: Icons.cloud_outlined,
            title: 'Data & Sync',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              SwitchListTile(
                title: const Text('Auto-Sync'),
                subtitle: const Text('Automatically sync infra when online'),
                value: _autoSync,
                onChanged: (value) {
                  setState(() => _autoSync = value);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Clear Cache'),
                subtitle: const Text('Free up storage space'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showClearCacheDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Export Data'),
                subtitle: const Text('Download your inspection infra'),
                trailing: const Icon(Icons.download_outlined),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export feature - Coming soon'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Advanced Section
          _SectionHeader(
            icon: Icons.settings_applications_outlined,
            title: 'Advanced',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              ListTile(
                title: const Text('Selection Options'),
                subtitle: const Text('Manage technicians, makes, and voltages'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/options');
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Debug Mode'),
                subtitle: const Text('Show debug information'),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debug mode - Coming soon'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Account Section
          if (userProfile != null) ...[
            _SectionHeader(
              icon: Icons.person_outline,
              title: 'Account',
              theme: theme,
            ),
            _SettingCard(
              theme: theme,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userProfile.avatarUrl != null
                        ? NetworkImage(userProfile.avatarUrl!)
                        : null,
                    child: userProfile.avatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(userProfile.displayName),
                  subtitle: Text(userProfile.email),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password change - Coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'Sign Out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  trailing: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                  ),
                  onTap: () {
                    _showSignOutDialog(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          _SectionHeader(
            icon: Icons.info_outline,
            title: 'About',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              ListTile(
                title: const Text('About Voltcore'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/about');
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening privacy policy...'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening terms of service...'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              const ListTile(
                title: Text('Version'),
                trailing: Text('1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      badges: badges.toRouteMap(),
      userProfile: userProfile,
      onSwitchTenant: (tenant) {
        ref.read(currentTenantProvider.notifier).switchTenant(tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to $tenant')),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Spanish'),
              value: 'Spanish',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('French'),
              value: 'French',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFormatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('MM/DD/YYYY'),
              value: 'MM/DD/YYYY',
              groupValue: _dateFormat,
              onChanged: (value) {
                setState(() => _dateFormat = value!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('DD/MM/YYYY'),
              value: 'DD/MM/YYYY',
              groupValue: _dateFormat,
              onChanged: (value) {
                setState(() => _dateFormat = value!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('YYYY-MM-DD'),
              value: 'YYYY-MM-DD',
              groupValue: _dateFormat,
              onChanged: (value) {
                setState(() => _dateFormat = value!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached infra. Your inspection infra will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign out - Coming soon')),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeData theme;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final ThemeData theme;
  final List<Widget> children;

  const _SettingCard({
    required this.theme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}