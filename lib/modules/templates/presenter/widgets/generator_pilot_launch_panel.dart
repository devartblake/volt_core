import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../core/constants/route_paths.dart';

/// Technician-facing entry point for the controlled generator template pilot.
///
/// The panel is completely absent from normal production builds. It becomes
/// visible only when the compile-time pilot flag is enabled, while the router's
/// existing `template_response` RBAC remains the authorization boundary.
class GeneratorPilotLaunchPanel extends StatelessWidget {
  const GeneratorPilotLaunchPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.generatorTemplatePilotEnabled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.tertiaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.tertiary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generator Template Pilot',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.lock_clock_outlined, size: 16),
                  label: const Text('Controlled pilot'),
                  backgroundColor: colors.surface,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Start a revision-pinned inspection or maintenance response. '
              'Legacy generator workflows remain available for rollback and '
              'report comparison during Phase 3 certification.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      context.push(RoutePaths.generatorInspectionPilot),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Start inspection pilot'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(RoutePaths.generatorMaintenancePilot),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Start maintenance pilot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
