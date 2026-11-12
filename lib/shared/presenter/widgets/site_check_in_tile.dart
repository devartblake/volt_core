import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location/location_service.dart';
import '../../../core/services/location/site_check_in.dart';
import '../../../core/services/permissions/app_permissions.dart';
import '../../../core/theme/status_colors.dart';
import '../../widgets/widgets.dart';

/// "Check in" for a form — records where the work was done, once.
///
/// Shared by inspections and maintenance. Both are work performed *at a place*
/// and a second copy of this would drift; the only difference between the two
/// call sites is which entity holds the result.
class SiteCheckInTile extends StatefulWidget {
  const SiteCheckInTile({
    super.key,
    required this.checkIn,
    required this.onChanged,
    this.enabled = true,
  });

  /// The position already recorded, if any.
  final SiteCheckIn? checkIn;

  /// Called with a new position, or null when the technician clears it.
  final ValueChanged<SiteCheckIn?> onChanged;

  final bool enabled;

  @override
  State<SiteCheckInTile> createState() => _SiteCheckInTileState();
}

class _SiteCheckInTileState extends State<SiteCheckInTile> {
  bool _busy = false;

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);

    final result = await LocationService.instance.capture();

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case CheckInCaptured(:final checkIn):
        widget.onChanged(checkIn);
        // Say when the fix is weak rather than presenting a cell-tower
        // position as evidence of standing in the plant room.
        if (checkIn.quality.isWeak) {
          AppSnackBar.error(
            context,
            'Checked in, but the fix is ${checkIn.quality.label.toLowerCase()}. '
            'Re-check outside if this needs to be precise.',
          );
        } else {
          AppSnackBar.success(context, 'Checked in at ${checkIn.formatted}.');
        }

      case CheckInFailed(:final failure):
        AppSnackBar.error(
          context,
          failure.message,
          action: failure.opensAppSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: AppPermissions.openSettings,
                )
              : null,
        );
    }
  }

  Future<void> _openInMaps(SiteCheckIn checkIn) async {
    final uri = Uri.parse(checkIn.mapsUri);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No maps app could open that location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkIn = widget.checkIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              checkIn == null
                  ? Icons.location_off_outlined
                  : Icons.location_on_outlined,
              color: checkIn == null
                  ? theme.colorScheme.onSurfaceVariant
                  : (checkIn.quality.isWeak
                      ? theme.status.warning
                      : theme.status.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Site check-in', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  if (checkIn == null)
                    Text(
                      'Optional. Records where this work was done.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else ...[
                    Text(checkIn.formatted, style: theme.textTheme.bodyMedium),
                    Text(
                      [
                        checkIn.quality.label,
                        if (checkIn.accuracyMeters != null)
                          '±${checkIn.accuracyMeters!.round()} m',
                      ].join('  ·  '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: checkIn.quality.isWeak
                            ? theme.status.warning
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              if (checkIn != null) ...[
                IconButton(
                  tooltip: 'Open in maps',
                  icon: const Icon(Icons.map_outlined),
                  onPressed: () => _openInMaps(checkIn),
                ),
                IconButton(
                  tooltip: 'Clear check-in',
                  icon: const Icon(Icons.clear),
                  onPressed:
                      widget.enabled ? () => widget.onChanged(null) : null,
                ),
              ],
              TextButton.icon(
                onPressed: widget.enabled ? _capture : null,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(checkIn == null ? 'Check in' : 'Re-check'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
