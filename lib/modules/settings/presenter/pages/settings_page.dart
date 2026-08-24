import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_roles.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../inspections/presenter/controllers/user_profile_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notifications = true;
  bool _autoSync = true;
  String _language = 'English';
  String _dateFormat = 'MM/DD/YYYY';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileProvider);
    final auth = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final canManageTemplates = RouteRoles.isAllowedByName(
      name: RouteNames.templates,
      role: auth.currentRole,
    );
    final canOpenDebug = kDebugMode &&
        RouteRoles.isAllowedByName(name: 'debug_menu', role: auth.currentRole);

    return AppPage(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                value: themeMode == ThemeMode.dark,
                onChanged: (value) =>
                    ref.read(themeModeProvider.notifier).setDarkMode(value),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(_language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChoiceDialog(
                  context: context,
                  title: 'Select Language',
                  options: const ['English', 'Spanish', 'French'],
                  selected: _language,
                  onSelected: (value) => setState(() => _language = value),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Date Format'),
                subtitle: Text(_dateFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChoiceDialog(
                  context: context,
                  title: 'Select Date Format',
                  options: const ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD'],
                  selected: _dateFormat,
                  onSelected: (value) => setState(() => _dateFormat = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                onChanged: (value) => setState(() => _notifications = value),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                subtitle: const Text('Automatically sync data when online'),
                value: _autoSync,
                onChanged: (value) => setState(() => _autoSync = value),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Documents'),
                subtitle: const Text('View, share and email generated reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RoutePaths.documents),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Clear Cache'),
                subtitle: const Text('Free up storage space'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showClearCacheDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Export Data'),
                subtitle: const Text('Download your inspection data'),
                trailing: const Icon(Icons.download_outlined),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature - Coming soon')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.settings_applications_outlined,
            title: 'Advanced',
            theme: theme,
          ),
          _SettingCard(
            theme: theme,
            children: [
              if (canManageTemplates) ...[
                ListTile(
                  leading: const Icon(Icons.dynamic_form_outlined),
                  title: const Text('Template Management'),
                  subtitle: const Text(
                    'Install and manage inspection and maintenance templates',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RoutePaths.templates),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                title: const Text('Selection Options'),
                subtitle: const Text('Manage technicians, makes, and voltages'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RoutePaths.selectionManagement),
              ),
              if (canOpenDebug) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Debug Tools'),
                  subtitle: const Text('Inspect local storage and network activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/debug'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
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
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password securely'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'Sign Out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  trailing: Icon(Icons.logout, color: theme.colorScheme.error),
                  onTap: () => _showSignOutDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
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
                onTap: () => context.push(RoutePaths.about),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening privacy policy...')),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening terms of service...')),
                ),
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
    );
  }

  void _showChoiceDialog({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) onSelected(value);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                RadioListTile<String>(title: Text(option), value: option),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    var obscurePassword = true;
    var obscureConfirm = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enabled: !saving,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        onPressed: saving
                            ? null
                            : () => setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a new password.';
                      }
                      if (value.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      suffixIcon: IconButton(
                        onPressed: saving
                            ? null
                            : () => setDialogState(
                                  () => obscureConfirm = !obscureConfirm,
                                ),
                        icon: Icon(
                          obscureConfirm ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!saving) {
                        _submitPasswordChange(
                          dialogContext: dialogContext,
                          formKey: formKey,
                          newPassword: passwordController.text,
                          setSaving: (value) =>
                              setDialogState(() => saving = value),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () => _submitPasswordChange(
                        dialogContext: dialogContext,
                        formKey: formKey,
                        newPassword: passwordController.text,
                        setSaving: (value) =>
                            setDialogState(() => saving = value),
                      ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _submitPasswordChange({
    required BuildContext dialogContext,
    required GlobalKey<FormState> formKey,
    required String newPassword,
    required ValueChanged<bool> setSaving,
  }) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setSaving(true);
    try {
      await ref.read(authStateProvider.notifier).changePassword(newPassword);
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } catch (error) {
      if (!mounted || !dialogContext.mounted) return;
      setSaving(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update password: $error')),
      );
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear cached data. Synced inspection data is not removed.',
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
    showDialog<void>(
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
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

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(children: children),
      );
}
