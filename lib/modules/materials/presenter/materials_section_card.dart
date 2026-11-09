import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../permissions/domain/permission.dart';
import '../../permissions/presenter/permission_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/domain/user_role.dart';
import '../domain/material_item.dart';
import '../domain/material_list.dart';
import '../infra/materials_repository.dart';
import 'materials_editor.dart';
import 'profile_proposal_sheet.dart';

/// Who may change a generator's standing parts list. Technicians record what
/// they find and use on a job, and propose profile changes to a supervisor.
bool canEditGeneratorProfile(UserRole? role) =>
    Permission.editPartsProfiles.defaultFor(role);

/// The Materials block used in the inspection and maintenance forms: a title,
/// the editor, and a way to open the generator's profile.
class MaterialsSectionCard extends ConsumerWidget {
  const MaterialsSectionCard({
    super.key,
    required this.owner,
    required this.mode,
    required this.make,
    required this.model,
    required this.serial,
    this.title = 'Parts & Materials',
    this.subtitle,
    this.seed,
    this.onChanged,
  });

  /// The job these parts belong to (an inspection or maintenance record).
  final MaterialOwner owner;
  final MaterialsMode mode;

  /// The generator this job is for; its parts profile is keyed from these.
  final String make;
  final String model;
  final String serial;

  final String title;
  final String? subtitle;
  final List<MaterialItem> Function()? seed;
  final ValueChanged<List<MaterialItem>>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canEdit = ref.watch(hasPermissionProvider(Permission.editPartsProfiles));

    final key = generatorProfileKey(make: make, model: model, serial: serial);
    final profile = key.isEmpty
        ? null
        : MaterialOwner.generator(
            key: key, make: make.trim(), model: model.trim(), serial: serial.trim());

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      color: scheme.onSecondaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                if (profile != null)
                  TextButton.icon(
                    onPressed: () => showGeneratorPartsProfile(
                      context,
                      make: make,
                      model: model,
                      serial: serial,
                    ),
                    icon: const Icon(Icons.precision_manufacturing_outlined),
                    label: const Text('Profile'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (profile == null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Enter the generator\'s make, model or serial number on the '
                  'site step to link these parts to its profile.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            MaterialsEditor(
              owner: owner,
              mode: mode,
              profileOwner: profile,
              canEditProfile: canEdit,
              seed: seed,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// A generator's parts profile in a full-height sheet. Admins, supervisors and
/// dispatchers edit it; technicians read it.
Future<void> showGeneratorPartsProfile(
  BuildContext context, {
  required String make,
  required String model,
  required String serial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _ProfileSheet(make: make, model: model, serial: serial),
    ),
  );
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet({
    required this.make,
    required this.model,
    required this.serial,
  });

  final String make;
  final String model;
  final String serial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canEdit = ref.watch(hasPermissionProvider(Permission.editPartsProfiles));
    final key = generatorProfileKey(make: make, model: model, serial: serial);
    final name = [make, model].where((s) => s.trim().isNotEmpty).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generator parts profile',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        if (name.isNotEmpty) name,
                        if (serial.trim().isNotEmpty) 'SN ${serial.trim()}',
                      ].join('  ·  '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // Technicians: "Propose a change" and their own requests. Editors: a
        // "N waiting" chip to the approvals page.
        ProfileRequestsPanel(
          canEdit: canEdit,
          make: make,
          model: model,
          serial: serial,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: key.isEmpty
                ? const Text('This generator has no make, model or serial yet.')
                : MaterialsEditor(
                    owner: MaterialOwner.generator(
                      key: key,
                      make: make.trim(),
                      model: model.trim(),
                      serial: serial.trim(),
                    ),
                    mode: MaterialsMode.profile,
                    readOnly: !canEdit,
                  ),
          ),
        ),
      ],
    );
  }
}
