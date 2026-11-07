import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../domain/daily_check_status.dart';
import '../../infra/repositories/vehicle_inspection_repository.dart';

/// Badge for [state]: Done today / Due / Overdue.
class DailyCheckChip extends StatelessWidget {
  const DailyCheckChip({super.key, required this.state});

  final DailyCheckState state;

  @override
  Widget build(BuildContext context) => switch (state) {
        DailyCheckState.doneToday => const StatusChip(
            label: 'Daily check: done today',
            tone: StatusTone.success,
            icon: Icons.check_circle_outline,
          ),
        DailyCheckState.due => const StatusChip(
            label: 'Daily check: due',
            tone: StatusTone.warning,
            icon: Icons.schedule,
          ),
        DailyCheckState.overdue => const StatusChip(
            label: 'Daily check: overdue',
            tone: StatusTone.danger,
            icon: Icons.warning_amber_rounded,
          ),
      };
}

/// [DailyCheckChip] for one vehicle, from its inspection history. Renders
/// nothing while loading or when the history cannot be read.
class VehicleDailyCheckChip extends ConsumerWidget {
  const VehicleDailyCheckChip({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vehicleInspectionsProvider(vehicleId)).maybeWhen(
          data: (list) => dailyCheckState(list),
          orElse: () => null,
        );
    return state == null ? const SizedBox.shrink() : DailyCheckChip(state: state);
  }
}
