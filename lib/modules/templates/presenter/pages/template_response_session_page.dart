import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_page.dart';
import '../controllers/template_response_session_controller.dart';
import '../widgets/template_form_renderer.dart';

class TemplateResponseSessionPage extends StatelessWidget {
  const TemplateResponseSessionPage({
    super.key,
    required this.controller,
    required this.completedByUserId,
    this.title,
    this.attachmentFieldBuilder,
  });

  final TemplateResponseSessionController controller;
  final String completedByUserId;
  final String? title;
  final TemplateAttachmentFieldBuilder? attachmentFieldBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final locked = controller.isLocked;
        return AppPage(
          title: title ?? controller.definition.revision.title,
          actions: [
            if (controller.isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (controller.response.isComplete)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Chip(label: Text('Completed'))),
              ),
          ],
          bottomBar: _SessionBottomBar(
            controller: controller,
            completedByUserId: completedByUserId,
          ),
          body: TemplateFormRenderer(
            definition: controller.definition,
            values: controller.values,
            validationIssues: controller.issues,
            readOnly: locked,
            attachmentFieldBuilder: attachmentFieldBuilder,
            onChanged: controller.setValue,
          ),
        );
      },
    );
  }
}

class _SessionBottomBar extends StatelessWidget {
  const _SessionBottomBar({
    required this.controller,
    required this.completedByUserId,
  });

  final TemplateResponseSessionController controller;
  final String completedByUserId;

  @override
  Widget build(BuildContext context) {
    final error = controller.lastSaveError;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: error == null
                    ? Text(
                        controller.response.isComplete
                            ? 'This response is complete and locked.'
                            : controller.isSaving
                                ? 'Saving draft locally…'
                                : 'Draft changes are saved locally and queued for sync.',
                      )
                    : Text(
                        'Draft save failed: $error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              if (error != null && !controller.isLocked)
                OutlinedButton.icon(
                  onPressed: controller.flush,
                  icon: const Icon(Icons.sync),
                  label: const Text('Retry save'),
                ),
              if (!controller.response.isComplete) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: controller.isLocked
                      ? null
                      : () async {
                          final result = await controller.complete(
                            completedByUserId: completedByUserId,
                          );
                          if (!context.mounted) return;
                          if (!result.completed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${result.issues.length} field issue(s) must be corrected before completion.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Complete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
