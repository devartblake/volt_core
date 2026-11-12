import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/storage/file_storage_service.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/asset_disclaimer.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_check.dart';
import '../../infra/repositories/vehicle_asset_check_repository.dart';
import '../../infra/services/asset_receipt_pdf_service.dart';
import '../fleet_providers.dart';
import '../widgets/asset_disclaimer_dialog.dart';
import '../widgets/signature_pad_dialog.dart';

/// The signed asset receipt — the screen that replaces the paper form.
///
/// The flow it implements, in order, because the order is the point:
///
///   1. dispatch fills in the header and walks the tool list with the driver;
///   2. the driver is shown the disclaimer and has to accept it;
///   3. the driver signs, and the tool answers become the van's standing state;
///   4. dispatch counter-signs as a second verification, which freezes the
///      receipt for good.
class VehicleAssetReceiptPage extends ConsumerStatefulWidget {
  const VehicleAssetReceiptPage({
    super.key,
    required this.vehicleId,
    this.checkId,
  });

  final String vehicleId;

  /// Null starts a new receipt. Otherwise the existing one is opened — to
  /// counter-sign it, or to read one already complete.
  final String? checkId;

  @override
  ConsumerState<VehicleAssetReceiptPage> createState() =>
      _VehicleAssetReceiptPageState();
}

class _VehicleAssetReceiptPageState
    extends ConsumerState<VehicleAssetReceiptPage> {
  VehicleAssetCheck? _check;
  AssetDisclaimer? _disclaimer;
  Object? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(vehicleAssetCheckRepositoryProvider);
    try {
      final disclaimer = await repository.currentDisclaimer();

      VehicleAssetCheck? check;
      if (widget.checkId == null) {
        final draft = await repository.startReceipt(widget.vehicleId);
        // Prefill the operator from whoever the van is stationed to, so the
        // common case is a glance rather than typing. Dispatch can overwrite
        // it: the person who actually drives today is what gets recorded.
        check = draft.copyWith(operatorName: await _assignedDriverName() ?? '');
      } else {
        final all = await repository.listForVehicle(widget.vehicleId);
        for (final candidate in all) {
          if (candidate.id == widget.checkId) check = candidate;
        }
        if (check == null) {
          throw StateError('That receipt is not on this device.');
        }
      }

      if (!mounted) return;
      setState(() {
        _disclaimer = disclaimer;
        _check = check;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<String?> _assignedDriverName() async {
    final vehicle = await ref.read(vehicleProvider(widget.vehicleId).future);
    final assignedTo = vehicle?.assignedToUserId;
    if (assignedTo == null || assignedTo.isEmpty) return null;

    final members = await ref.read(fleetAssignableMembersProvider.future);
    for (final member in members) {
      if (member.userId == assignedTo) return member.displayName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final error = _loadError;
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));

    return AppPage(
      title: vehicle.asData?.value == null
          ? 'Asset Receipt'
          : 'Receipt · ${vehicle.asData!.value!.displayTitle}',
      actions: [
        if (check != null && check.isSignedByOperator)
          IconButton(
            tooltip: 'Print receipt',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _busy ? null : _print,
          ),
      ],
      body: error != null
          ? EmptyState.error(
              message: '$error',
              action: FilledButton.tonal(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                child: const Text('Retry'),
              ),
            )
          : check == null
              ? const Center(child: CircularProgressIndicator())
              : _body(check),
    );
  }

  Widget _body(VehicleAssetCheck check) {
    final theme = Theme.of(context);
    final isManager = ref.watch(fleetManagerProvider);

    // Once the driver has signed, the answers they signed for are settled. Only
    // dispatch's own fields stay live, until they counter-sign and nothing
    // does.
    final linesLocked = check.isSignedByOperator;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StageBanner(stage: check.stage, missing: check.missingCount),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Who is taking the vehicle',
          icon: Icons.badge_outlined,
          children: [
            LabeledField(
              label: 'Operator (driver)',
              value: check.operatorName,
              required: true,
              enabled: !linesLocked,
              prefixIcon: Icons.person_outline,
              onChanged: (v) => _mutate((c) => c.copyWith(operatorName: v)),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Co-operator',
              value: check.coOperatorName,
              helper: 'Optional. The second person in the van.',
              enabled: !linesLocked,
              prefixIcon: Icons.person_add_alt,
              onChanged: (v) => _mutate((c) => c.copyWith(coOperatorName: v)),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Dispatcher',
              value: check.dispatcherName,
              required: true,
              enabled: !check.isCounterSigned,
              prefixIcon: Icons.headset_mic_outlined,
              onChanged: (v) => _mutate((c) => c.copyWith(dispatcherName: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tools (${check.lines.length})',
          icon: Icons.handyman_outlined,
          subtitle: linesLocked
              ? 'Signed for — no longer editable.'
              : 'Everything starts serviceable and present. Mark the '
                  'exceptions.',
          children: [
            if (check.lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'This vehicle has no tools assigned, so there is nothing to '
                  'sign for. Add them under Assets first.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final line in check.lines)
                _LineTile(
                  key: ValueKey(line.id),
                  line: line,
                  enabled: !linesLocked,
                  onChanged: (updated) => _mutate((c) => c.withLine(updated)),
                  onToggled: () => setState(() {}),
                  // Raising the job is dispatch's call, and only once the
                  // receipt is signed — before that the line is still being
                  // argued about in the yard.
                  onRaiseWorkOrder: isManager && check.isSignedByOperator
                      ? () => _raiseWorkOrder(check, line)
                      : null,
                ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Notes',
          icon: Icons.sticky_note_2_outlined,
          children: [
            LabeledField(
              label: 'Notes',
              value: check.notes,
              maxLines: 3,
              enabled: !check.isCounterSigned,
              onChanged: (v) => _mutate((c) => c.copyWith(notes: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Signatures',
          icon: Icons.draw_outlined,
          subtitle: _disclaimer == null
              ? null
              : 'Asset disclaimer version ${_disclaimer!.version}',
          children: [
            _SignatureRow(
              role: 'Operator',
              name: check.operatorName,
              signedAt: check.operatorSignedAt,
              icon: Icons.draw_outlined,
            ),
            if (!check.isSignedByOperator) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _signAsOperator,
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Read disclaimer and sign'),
              ),
            ],
            const SizedBox(height: 20),
            _SignatureRow(
              role: 'Dispatcher',
              name: check.dispatcherName,
              signedAt: check.dispatcherSignedAt,
              icon: Icons.verified_outlined,
            ),
            if (check.isSignedByOperator && !check.isCounterSigned) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy || !isManager ? null : _counterSign,
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  isManager
                      ? 'Verify and counter-sign'
                      : 'Dispatch verifies this receipt',
                ),
              ),
            ],
            if (check.isCounterSigned) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete. A counter-signed receipt cannot be changed.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (!check.isCounterSigned)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _save(announce: true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
      ],
    );
  }

  /// Apply an edit without rebuilding the whole list.
  ///
  /// Text fields run uncontrolled — rebuilding on every keystroke would fight
  /// the cursor. Anything that changes what is *shown* calls setState itself.
  void _mutate(VehicleAssetCheck Function(VehicleAssetCheck) transform) {
    final current = _check;
    if (current == null) return;
    _check = transform(current);
  }

  Future<void> _signAsOperator() async {
    final check = _check;
    final disclaimer = _disclaimer;
    if (check == null || disclaimer == null) return;

    // Everything except the disclaimer itself, which is the very next step.
    final blocking = check.problemsBeforeSigning
        .where((p) => !p.contains('asset disclaimer'))
        .toList();
    if (blocking.isNotEmpty) {
      _showProblems('Not ready to sign', blocking);
      return;
    }

    final accepted = await showAssetDisclaimerDialog(
      context: context,
      disclaimer: disclaimer,
      operatorName: check.operatorName,
    );
    if (accepted != true || !mounted) return;

    final acceptedAt = DateTime.now().toUtc();

    final bytes = await showSignaturePad(
      context: context,
      title: 'Operator signature',
      subtitle: '${check.operatorName.trim()} — accepting version '
          '${disclaimer.version} of the asset disclaimer',
    );
    if (bytes == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final storedPath = await FileStorageService.instance.saveFleetSignature(
        checkId: check.id,
        role: 'operator',
        signatureBytes: bytes,
      );

      _mutate(
        (c) => c.copyWith(
          disclaimerVersion: disclaimer.version,
          disclaimerAcceptedAt: acceptedAt,
          operatorUserId: ref.read(authStateProvider).userId,
          operatorSignaturePath: storedPath,
          operatorSignedAt: DateTime.now().toUtc(),
        ),
      );
      await _save(announce: false);
      if (mounted) AppSnackBar.success(context, 'Signed.');
    } catch (error) {
      if (mounted) AppSnackBar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _counterSign() async {
    final check = _check;
    if (check == null) return;

    final blocking = check.problemsBeforeCountersigning;
    if (blocking.isNotEmpty) {
      _showProblems('Not ready to verify', blocking);
      return;
    }

    final bytes = await showSignaturePad(
      context: context,
      title: 'Dispatcher verification',
      subtitle: '${check.dispatcherName.trim()} — verifying what the operator '
          'signed for',
    );
    if (bytes == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final storedPath = await FileStorageService.instance.saveFleetSignature(
        checkId: check.id,
        role: 'dispatcher',
        signatureBytes: bytes,
      );

      _mutate(
        (c) => c.copyWith(
          dispatcherUserId: ref.read(authStateProvider).userId,
          dispatcherSignaturePath: storedPath,
          dispatcherSignedAt: DateTime.now().toUtc(),
        ),
      );
      await _save(announce: false);
      if (mounted) AppSnackBar.success(context, 'Receipt complete.');
    } catch (error) {
      if (mounted) AppSnackBar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({required bool announce}) async {
    final check = _check;
    if (check == null) return;

    final saved =
        await ref.read(vehicleAssetCheckRepositoryProvider).save(check);
    if (!mounted) return;

    setState(() => _check = saved);
    // The van's standing state may have just changed, so anything showing
    // "missing" has to be recomputed.
    ref.invalidate(vehicleAssetsProvider(widget.vehicleId));
    ref.invalidate(vehicleReceiptsProvider(widget.vehicleId));
    ref.invalidate(fleetAttentionProvider);

    if (announce) AppSnackBar.success(context, 'Draft saved.');
  }

  /// Open a prefilled work-order draft for one problem line.
  ///
  /// Nothing is created here. Dispatch reviews the draft and saves it, because
  /// auto-creating a job for every reported problem is how a job list stops
  /// being read.
  Future<void> _raiseWorkOrder(
    VehicleAssetCheck check,
    VehicleAssetCheckLine line,
  ) async {
    final vehicle = await ref.read(vehicleProvider(widget.vehicleId).future);
    if (!mounted) return;

    final where = vehicle?.displayTitle ?? 'vehicle';
    final what = line.isMissing ? 'Missing' : 'Not mission capable';

    final description = [
      '$what: ${line.displayLabel}',
      if (line.serialNumber.isNotEmpty) 'Serial: ${line.serialNumber}',
      if (line.reason.trim().isNotEmpty) 'Reported reason: ${line.reason.trim()}',
      'From the asset receipt signed '
          '${formatReceiptStamp(check.operatorSignedAt ?? check.checkedAt)}'
          '${check.operatorName.trim().isEmpty ? '' : ' by ${check.operatorName.trim()}'}.',
    ].join('\n');

    if (!mounted) return;
    context.push(
      Uri(
        path: RoutePaths.workOrderNew,
        queryParameters: {
          'title': '$what: ${line.assetName} · $where',
          'description': description,
          'vehicleId': check.vehicleId,
          'assetCheckLineId': line.id,
        },
      ).toString(),
    );
  }

  Future<void> _print() async {
    final check = _check;
    final disclaimer = _disclaimer;
    if (check == null || disclaimer == null) return;

    setState(() => _busy = true);
    try {
      // The version that was SIGNED, not the current one. Reprinting an old
      // receipt with today's clauses would misstate what the person agreed to.
      final signedVersion = disclaimer.version == check.disclaimerVersion
          ? disclaimer
          : await ref
              .read(vehicleAssetCheckRepositoryProvider)
              .disclaimerVersion(check.disclaimerVersion);

      final path = await AssetReceiptPdfService.instance.generate(
        check: check,
        vehicle: await ref.read(vehicleProvider(widget.vehicleId).future),
        disclaimer: signedVersion,
      );
      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Receipt saved.',
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => OpenFilex.open(path),
        ),
      );
    } catch (error) {
      if (mounted) AppSnackBar.error(context, 'Could not build the PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showProblems(String title, List<String> problems) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final problem in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(problem)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.stage, required this.missing});

  final ReceiptStage stage;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (background, icon, message) = switch (stage) {
      ReceiptStage.draft => (
          theme.colorScheme.surfaceContainerHighest,
          Icons.edit_outlined,
          'Draft — nothing is binding until the operator signs.',
        ),
      ReceiptStage.awaitingCountersign => (
          theme.colorScheme.tertiaryContainer,
          Icons.hourglass_bottom,
          'Signed by the operator. Waiting on dispatch to verify.',
        ),
      ReceiptStage.complete => (
          theme.status.successContainer,
          Icons.check_circle_outline,
          'Complete and locked.',
        ),
    };

    // onSurface rather than a matching on* token: StatusColors has no
    // onSuccessContainer, and onSurface reads correctly against all three
    // backgrounds in both themes.
    final foreground = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: foreground)),
                if (missing > 0)
                  Text(
                    missing == 1
                        ? '1 tool reported missing'
                        : '$missing tools reported missing',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.role,
    required this.name,
    required this.signedAt,
    required this.icon,
  });

  final String role;
  final String name;
  final DateTime? signedAt;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signed = signedAt != null;

    return Row(
      children: [
        Icon(
          signed ? Icons.check_circle : icon,
          color: signed ? theme.status.success : theme.colorScheme.outline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: theme.textTheme.labelLarge),
              Text(
                signed
                    ? '${name.trim().isEmpty ? 'Signed' : name.trim()} · '
                        '${formatReceiptStamp(signedAt!)}'
                    : 'Not signed yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `2026-09-16 07:42` in local time. Shared with the receipt list so one
/// timestamp is not formatted two ways on two screens.
String formatReceiptStamp(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// One tool's line on the receipt.
class _LineTile extends StatefulWidget {
  const _LineTile({
    super.key,
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onToggled,
    this.onRaiseWorkOrder,
  });

  final VehicleAssetCheckLine line;
  final bool enabled;
  final ValueChanged<VehicleAssetCheckLine> onChanged;

  /// Null when this person cannot raise jobs, or the receipt is not signed yet.
  final VoidCallback? onRaiseWorkOrder;

  /// Called when something that changes the tile's shape is toggled, so the
  /// page can rebuild. Text edits deliberately do not.
  final VoidCallback onToggled;

  @override
  State<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<_LineTile> {
  late VehicleAssetCheckLine _line = widget.line;

  void _update(VehicleAssetCheckLine next, {bool rebuild = true}) {
    _line = next;
    widget.onChanged(next);
    if (rebuild) {
      setState(() {});
      widget.onToggled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsReason = _line.isMissing || _line.readiness == AssetReadiness.nmc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _line.isException
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_line.displayLabel, style: theme.textTheme.titleSmall),
              if (_line.serialNumber.isNotEmpty)
                Text(
                  'S/N ${_line.serialNumber}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
              SegmentedButton<AssetReadiness>(
                segments: const [
                  ButtonSegment(
                    value: AssetReadiness.fmc,
                    label: Text('FMC'),
                  ),
                  ButtonSegment(
                    value: AssetReadiness.nmc,
                    label: Text('NMC'),
                  ),
                ],
                selected: {_line.readiness},
                showSelectedIcon: false,
                onSelectionChanged: widget.enabled
                    ? (values) =>
                        _update(_line.copyWith(readiness: values.first))
                    : null,
              ),
              StatusSwitchTile(
                label: 'Missing',
                icon: Icons.help_outline,
                value: _line.isMissing,
                accent: StatusTileAccent.error,
                margin: const EdgeInsets.only(top: 8),
                onChanged: widget.enabled
                    ? (v) => _update(_line.copyWith(isMissing: v))
                    : null,
              ),
              if (needsReason)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LabeledField(
                    label: 'Reason',
                    value: _line.reason,
                    required: _line.isMissing,
                    enabled: widget.enabled,
                    helper: _line.isMissing
                        ? 'Required for a missing tool.'
                        : 'What is wrong with it?',
                    maxLines: 2,
                    onChanged: (v) =>
                        _update(_line.copyWith(reason: v), rebuild: false),
                  ),
                ),
              if (_line.isException && widget.onRaiseWorkOrder != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: widget.onRaiseWorkOrder,
                      icon: const Icon(Icons.assignment_add, size: 18),
                      label: const Text('Raise work order'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
