import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/nav_extensions.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../infra/repositories/vehicle_repository_impl.dart';
import '../fleet_providers.dart';

/// Add or edit a vehicle. Dispatch-only; a technician signs for a vehicle but
/// does not edit the fleet record.
class VehicleFormPage extends ConsumerStatefulWidget {
  const VehicleFormPage({super.key, this.id});

  /// Null when adding.
  final String? id;

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();

  VehicleEntity? _vehicle;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id == null) {
      final tenantId = SyncContext.tenantId;
      setState(() {
        _loading = false;
        _loadError = tenantId == null || tenantId.isEmpty
            ? 'No active tenant is configured, so a vehicle cannot be saved. '
                'Set SUPABASE_TENANT_ID and restart.'
            : null;
        _vehicle = tenantId == null || tenantId.isEmpty
            ? null
            : VehicleEntity.newDraft(tenantId: tenantId);
      });
      return;
    }

    try {
      final found = await ref.read(vehicleRepositoryProvider).getById(id);
      if (!mounted) return;
      setState(() {
        _vehicle = found;
        _loading = false;
        _loadError = found == null ? 'That vehicle was not found.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
    }
  }

  void _update(VehicleEntity Function(VehicleEntity) transform) {
    final current = _vehicle;
    if (current == null) return;
    setState(() => _vehicle = transform(current));
  }

  Future<void> _save() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(vehicleRepositoryProvider).save(vehicle);
      ref.invalidate(fleetVisibleVehiclesProvider);
      ref.invalidate(vehicleProvider(vehicle.id));
      if (!mounted) return;
      AppSnackBar.success(context, 'Saved ${vehicle.displayTitle}.');
      context.popOrGo(RoutePaths.fleet);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Duplicate designation and duplicate VIN both arrive here, and both are
      // worth reading in full rather than as a toast that disappears.
      AppSnackBar.error(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;

    return AppPage(
      title: widget.id == null ? 'Add Vehicle' : 'Edit Vehicle',
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vehicle == null) {
            return EmptyState.error(
              title: 'Cannot edit this vehicle',
              message: _loadError,
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                LabeledField(
                  label: 'Designation',
                  value: vehicle.designation,
                  required: true,
                  hint: 'Truck A',
                  helper: 'What the crew calls it. Heads every form.',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Give the vehicle a designation.'
                      : null,
                  onChanged: (v) =>
                      _update((curr) => curr.copyWith(designation: v)),
                ),
                SelectionField<VehicleType>(
                  label: 'Type',
                  value: vehicle.vehicleType,
                  options: VehicleType.values,
                  labelOf: (type) => type.label,
                  onChanged: (v) => _update(
                    (curr) => curr.copyWith(vehicleType: v ?? curr.vehicleType),
                  ),
                ),
                LabeledField(
                  label: 'Make',
                  value: vehicle.make,
                  hint: 'Ford',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => _update((curr) => curr.copyWith(make: v)),
                ),
                LabeledField(
                  label: 'Model',
                  value: vehicle.model,
                  hint: 'Transit',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => _update((curr) => curr.copyWith(model: v)),
                ),
                LabeledField(
                  label: 'VIN',
                  value: vehicle.vin ?? '',
                  hint: '17 characters',
                  helper: 'Optional — add it once someone reads it off the '
                      'vehicle.',
                  prefixIcon: Icons.tag_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: validateVin,
                  onChanged: (v) => _update(
                    (curr) => curr.copyWith(
                      vin: v.trim().isEmpty ? null : v,
                      clearVin: v.trim().isEmpty,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'License Plate',
                        value: vehicle.licensePlate,
                        hint: 'ABC-1234',
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) =>
                            _update((curr) => curr.copyWith(licensePlate: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledField(
                        label: 'Year',
                        value: vehicle.modelYear?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (v) => _update(
                          (curr) => curr.copyWith(
                            modelYear: int.tryParse(v.trim()),
                            clearModelYear: v.trim().isEmpty,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                LabeledField(
                  label: 'Odometer',
                  value: vehicle.odometer == 0
                      ? ''
                      : vehicle.odometer.toString(),
                  suffixText: 'mi',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _update(
                    (curr) =>
                        curr.copyWith(odometer: int.tryParse(v.trim()) ?? 0),
                  ),
                ),
                SelectionField<VehicleStatus>(
                  label: 'Status',
                  value: vehicle.status,
                  options: VehicleStatus.values,
                  labelOf: (status) => status.label,
                  onChanged: (v) => _update(
                    (curr) => curr.copyWith(status: v ?? curr.status),
                  ),
                ),
                _AssigneeField(
                  vehicle: vehicle,
                  onChanged: (userId) => _update(
                    (curr) => curr.copyWith(
                      assignedToUserId: userId,
                      clearAssignee: userId == null,
                    ),
                  ),
                ),
                LabeledField(
                  label: 'Notes',
                  value: vehicle.notes,
                  maxLines: 3,
                  onChanged: (v) => _update((curr) => curr.copyWith(notes: v)),
                ),
              ],
            ),
          );
        },
      ),
      bottomBar: vehicle == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving…' : 'Save Vehicle'),
              ),
            ),
    );
  }
}

/// Who is stationed to this vehicle.
///
/// Not just a detail: this is what lets the technician see the vehicle at all.
/// RLS grants a tech read access to the row whose `assigned_to_user_id` is
/// theirs, so clearing this takes the vehicle off their device.
const String _unassigned = '';

class _AssigneeField extends ConsumerWidget {
  const _AssigneeField({required this.vehicle, required this.onChanged});

  final VehicleEntity vehicle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(fleetAssignableMembersProvider);

    return members.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading team…'),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.person_off_outlined),
        title: const Text('Could not load the team'),
        subtitle: Text(
          'The vehicle can still be saved unassigned. $error',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // Sentinel '' rather than a nullable T: SelectionField renders a null
      // value as "nothing selected" and shows the hint, which would hide the
      // Unassigned row instead of selecting it.
      data: (list) => SelectionField<String>(
        label: 'Assigned technician',
        value: vehicle.assignedToUserId ?? _unassigned,
        options: <String>[_unassigned, ...list.map((m) => m.userId)],
        labelOf: (userId) {
          if (userId == _unassigned) return 'Unassigned';
          for (final member in list) {
            if (member.userId == userId) {
              return '${member.displayName} (${member.role.label})';
            }
          }
          // Assigned to somebody no longer on the team. Saying so beats
          // rendering a bare uuid or silently showing "Unassigned".
          return 'Former member';
        },
        onChanged: (userId) =>
            onChanged(userId == null || userId == _unassigned ? null : userId),
      ),
    );
  }
}
