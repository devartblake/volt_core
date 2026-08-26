import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/nav_extensions.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_maintenance_check.dart';
import '../../infra/repositories/vehicle_check_repository.dart';
import '../../infra/repositories/vehicle_repository_impl.dart';
import '../fleet_providers.dart';

/// Record a vehicle maintenance checklist. Mirrors the paper form.
class VehicleMaintenanceFormPage extends ConsumerStatefulWidget {
  const VehicleMaintenanceFormPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleMaintenanceFormPage> createState() =>
      _VehicleMaintenanceFormPageState();
}

class _VehicleMaintenanceFormPageState
    extends ConsumerState<VehicleMaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();

  VehicleEntity? _vehicle;
  VehicleMaintenanceCheck? _check;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'No active tenant is configured, so a check cannot be '
            'saved. Set SUPABASE_TENANT_ID and restart.';
      });
      return;
    }

    try {
      final vehicle =
          await ref.read(vehicleRepositoryProvider).getById(widget.vehicleId);
      if (!mounted) return;

      setState(() {
        _vehicle = vehicle;
        _loading = false;
        _loadError = vehicle == null ? 'That vehicle was not found.' : null;
        _check = vehicle == null
            ? null
            // Pre-fill the reading the vehicle already carries: the common
            // action is typing the new mileage over the old, not from zero.
            : VehicleMaintenanceCheck.newDraft(
                tenantId: tenantId,
                vehicleId: vehicle.id,
                odometer: vehicle.odometer,
                checkedByUserId: SyncContext.userId,
              );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
    }
  }

  void _update(
    VehicleMaintenanceCheck Function(VehicleMaintenanceCheck) transform,
  ) {
    final current = _check;
    if (current == null) return;
    setState(() => _check = transform(current));
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      // A service date is in the past. Allowing next year invites a typo that
      // then reads as "serviced recently" forever.
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save({bool allowRollback = false}) async {
    final check = _check;
    if (check == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(vehicleCheckRepositoryProvider).save(
            check,
            allowOdometerRollback: allowRollback,
          );

      ref.invalidate(vehicleChecksProvider(check.vehicleId));
      ref.invalidate(vehicleProvider(check.vehicleId));
      ref.invalidate(fleetVisibleVehiclesProvider);

      if (!mounted) return;
      AppSnackBar.success(context, 'Check recorded.');
      context.popOrGo(RoutePaths.fleetDetail.replaceFirst(':id', check.vehicleId));
    } on OdometerWentBackwards catch (problem) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _confirmRollback(problem);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, '$error');
    }
  }

  /// A lower reading is almost always a transposed digit, but it is
  /// legitimately a correction after a cluster replacement. Ask rather than
  /// choosing for them — and make the numbers visible in the question.
  Future<void> _confirmRollback(OdometerWentBackwards problem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Odometer went backwards'),
        content: Text(
          'This check reads ${problem.recorded} miles, but the vehicle '
          'already shows ${problem.previous}.\n\n'
          'Check for a typo first. Only continue if the odometer really was '
          'replaced or corrected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back and fix it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('It is correct'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) await _save(allowRollback: true);
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final vehicle = _vehicle;

    return AppPage(
      title: vehicle == null
          ? 'Maintenance Check'
          : 'Check · ${vehicle.displayTitle}',
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (check == null || vehicle == null) {
            return EmptyState.error(
              title: 'Cannot record a check',
              message: _loadError,
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _DateField(
                  label: 'Date of check',
                  value: check.checkedAt,
                  onTap: () => _pickDate(
                    current: check.checkedAt,
                    onPicked: (picked) => _update(
                      (curr) => curr.copyWith(checkedAt: picked?.toUtc()),
                    ),
                  ),
                ),
                LabeledField(
                  label: 'Odometer',
                  value: check.odometer == 0 ? '' : check.odometer.toString(),
                  required: true,
                  suffixText: 'mi',
                  helper: 'Vehicle currently shows ${vehicle.odometer} mi.',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Record the mileage.'
                      : null,
                  onChanged: (v) => _update(
                    (curr) =>
                        curr.copyWith(odometer: int.tryParse(v.trim()) ?? 0),
                  ),
                ),
                const _SectionLabel('Service history'),
                _DateField(
                  label: 'Last oil change',
                  value: check.lastOilChangeAt,
                  onClear: check.lastOilChangeAt == null
                      ? null
                      : () => _update(
                            (curr) => curr.copyWith(clearLastOilChange: true),
                          ),
                  onTap: () => _pickDate(
                    current: check.lastOilChangeAt,
                    onPicked: (picked) => _update(
                      (curr) => curr.copyWith(lastOilChangeAt: picked),
                    ),
                  ),
                ),
                _DateField(
                  label: 'Last lubricant check',
                  value: check.lastLubricantCheckAt,
                  onClear: check.lastLubricantCheckAt == null
                      ? null
                      : () => _update(
                            (curr) =>
                                curr.copyWith(clearLastLubricantCheck: true),
                          ),
                  onTap: () => _pickDate(
                    current: check.lastLubricantCheckAt,
                    onPicked: (picked) => _update(
                      (curr) => curr.copyWith(lastLubricantCheckAt: picked),
                    ),
                  ),
                ),
                LabeledField(
                  label: 'Odometer at last service',
                  value: check.odometerAtLastService?.toString() ?? '',
                  suffixText: 'mi',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _update(
                    (curr) => curr.copyWith(
                      odometerAtLastService: int.tryParse(v.trim()),
                      clearOdometerAtLastService: v.trim().isEmpty,
                    ),
                  ),
                ),
                const _SectionLabel('Condition'),
                SelectionField<CheckStatus>(
                  label: 'Brakes',
                  value: check.brakeStatus,
                  options: CheckStatus.values,
                  labelOf: (status) => status.label,
                  onChanged: (v) => _update(
                    (curr) => curr.copyWith(brakeStatus: v ?? curr.brakeStatus),
                  ),
                ),
                SelectionField<CheckStatus>(
                  label: 'Battery',
                  value: check.batteryStatus,
                  options: CheckStatus.values,
                  labelOf: (status) => status.label,
                  onChanged: (v) => _update(
                    (curr) =>
                        curr.copyWith(batteryStatus: v ?? curr.batteryStatus),
                  ),
                ),
                LabeledField(
                  label: 'Notes',
                  value: check.notes,
                  maxLines: 3,
                  onChanged: (v) => _update((curr) => curr.copyWith(notes: v)),
                ),
              ],
            ),
          );
        },
      ),
      bottomBar: check == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving…' : 'Record Check'),
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// A read-only field that opens a date picker.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : formatShortDate(value!);

    return LabeledField(
      // Keyed on the value: LabeledField seeds its controller once, so without
      // this the field keeps showing the old date after a pick and the user
      // sees nothing happen. Same bug the inspection date fields had.
      key: ValueKey('$label:$text'),
      label: label,
      value: text,
      readOnly: true,
      hint: 'Not recorded',
      prefixIcon: Icons.event_outlined,
      onTap: onTap,
      suffix: onClear == null
          ? null
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear, size: 18),
              onPressed: onClear,
            ),
    );
  }
}

/// "5 Jun 2026". Short, unambiguous, and not locale-dependent about which
/// number is the month — which matters on a form read by two people.
String formatShortDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
