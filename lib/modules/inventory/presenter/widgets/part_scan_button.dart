import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../equipment/presenter/asset_code_scanner.dart';
import '../../domain/catalog_part.dart';
import '../../infra/inventory_repository.dart';
import '../inventory_access.dart';
import 'inventory_sheets.dart';

/// A Scan icon for a part search field. Hidden where the camera scanner is
/// not supported. [onScanned] gets the scanned text, trimmed and non-empty.
class PartScanButton extends ConsumerWidget {
  const PartScanButton({super.key, required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanner = ref.watch(assetCodeScannerProvider);
    if (!scanner.isSupported) return const SizedBox.shrink();
    return IconButton(
      key: const Key('scan_part'),
      tooltip: 'Scan a barcode',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        final code = await scanner.scan(context);
        final text = code?.trim() ?? '';
        if (text.isEmpty) return;
        onScanned(text);
      },
    );
  }
}

/// The catalog part whose number or alternate is exactly [code], or null.
Future<CatalogPart?> findScannedPart(WidgetRef ref, String code) async =>
    findPartByNumber(await ref.read(inventoryRepositoryProvider).parts(), code);

/// When nothing matches [code]: an admin is offered to add it to the catalog,
/// prefilled with the scanned number. Others get nothing.
Future<void> offerAddScannedPart(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  if (!ref.read(canManageInventoryProvider)) return;
  final add = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Not in the catalog'),
      content: Text('No part matches "$code".'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not now')),
        FilledButton(
            key: const Key('add_scanned_part'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Add this part')),
      ],
    ),
  );
  if (add == true && context.mounted) {
    await showPartEditorSheet(context, ref, initialNumber: code);
  }
}
