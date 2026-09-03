import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../domain/services/generator_pilot_readiness.dart';
import '../../domain/services/generator_pilot_resume.dart';
import '../../infra/repositories/form_response_repository_impl.dart';
import '../../infra/repositories/template_definition_repository_impl.dart';

final generatorPilotDraftsProvider =
    FutureProvider<List<GeneratorPilotResumeItem>>((ref) async {
  if (!FeatureFlags.generatorTemplatePilotEnabled) return const [];

  final tenantId = SyncContext.tenantId;
  if (tenantId == null || tenantId.isEmpty) return const [];

  final responseRepository = ref.watch(formResponseRepositoryProvider);
  final definitionRepository = ref.watch(templateDefinitionRepositoryProvider);
  final responses = await responseRepository.list();
  final templates = await definitionRepository.listTemplates();

  return GeneratorPilotResumeService.drafts(
    tenantId: tenantId,
    responses: responses,
    templates: templates,
  );
});

/// Offline-safe resume surface for locally persisted generator pilot drafts.
///
/// `FormResponseRepository.list` is Hive-backed, while the template repository
/// falls back to cached immutable definitions when Supabase is unavailable.
/// This lets the Phase 3 restart test resume the exact response without a
/// manually reconstructed URL.
class GeneratorPilotDraftsPanel extends ConsumerWidget {
  const GeneratorPilotDraftsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.generatorTemplatePilotEnabled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final drafts = ref.watch(generatorPilotDraftsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restore_page_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved pilot drafts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh saved pilot drafts',
                  onPressed: () => ref.invalidate(generatorPilotDraftsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            drafts.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => _DraftLoadError(
                message: error.toString(),
                onRetry: () => ref.invalidate(generatorPilotDraftsProvider),
              ),
              data: (items) => items.isEmpty
                  ? Text(
                      'No saved generator pilot drafts yet. Start a pilot '
                      'response online; it will appear here after local autosave.',
                      style: theme.textTheme.bodyMedium,
                    )
                  : Column(
                      children: [
                        for (final item in items) _DraftTile(item: item),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.item});

  final GeneratorPilotResumeItem item;

  @override
  Widget build(BuildContext context) {
    final response = item.response;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.template.slug == GeneratorPilotReadiness.inspectionSlug
            ? Icons.assignment_outlined
            : Icons.build_outlined,
      ),
      title: Text(item.template.name),
      subtitle: Text(
        'Draft • updated ${_formatTimestamp(response.updatedAt)} • '
        '${_shortId(response.id)}',
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: () => _resume(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Resume'),
      ),
    );
  }

  void _resume(BuildContext context) {
    final basePath = switch (item.template.slug) {
      GeneratorPilotReadiness.inspectionSlug =>
        RoutePaths.generatorInspectionPilot,
      GeneratorPilotReadiness.maintenanceSlug =>
        RoutePaths.generatorMaintenancePilot,
      _ => null,
    };
    if (basePath == null) return;

    final location = Uri(
      path: basePath,
      queryParameters: {'responseId': item.response.id},
    ).toString();
    context.push(location);
  }
}

class _DraftLoadError extends StatelessWidget {
  const _DraftLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sync_problem_outlined, color: colors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not load saved pilot drafts: $message',
            style: TextStyle(color: colors.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

String _shortId(String value) =>
    value.length <= 8 ? value : value.substring(0, 8);

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
