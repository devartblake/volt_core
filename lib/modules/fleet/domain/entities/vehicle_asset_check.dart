import 'package:uuid/uuid.dart';

import 'vehicle_asset.dart';
import 'vehicle_asset_catalog_item.dart';

/// How far along a receipt is.
///
/// Three states, not a boolean, because "the driver signed but dispatch has not
/// verified it yet" is a real queue somebody has to work through — and it is
/// the state a receipt spends most of its life in.
enum ReceiptStage {
  /// Being filled in. Nothing is binding yet.
  draft,

  /// The driver has signed. Waiting on dispatch to counter-sign.
  awaitingCountersign,

  /// Both signatures present. Immutable from here — the database enforces it.
  complete,
}

extension ReceiptStageX on ReceiptStage {
  String get label => switch (this) {
        ReceiptStage.draft => 'Draft',
        ReceiptStage.awaitingCountersign => 'Awaiting dispatch',
        ReceiptStage.complete => 'Complete',
      };
}

/// One tool on one receipt.
///
/// The tool's name, part number and serial are **copied in, not joined**. A
/// receipt is a record of what somebody signed for on a particular morning;
/// correcting a catalog typo in 2027 must not retroactively edit what was
/// printed on the page in 2026.
class VehicleAssetCheckLine {
  const VehicleAssetCheckLine({
    required this.id,
    required this.checkId,
    required this.tenantId,
    required this.assetName,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleAssetId,
    this.partNumber = '',
    this.serialNumber = '',
    this.quantity = 1,
    this.readiness = AssetReadiness.fmc,
    this.isMissing = false,
    this.reason = '',
    this.sortIndex = 0,
  });

  /// A line prefilled from what is currently assigned to the van.
  ///
  /// Starts FMC and not missing: the paper is a checklist the driver walks down
  /// ticking exceptions, not a survey they fill from nothing. [item] may be
  /// null when the catalog entry has not reached this device — the line still
  /// gets a printable name rather than being dropped.
  factory VehicleAssetCheckLine.fromAsset({
    required String checkId,
    required VehicleAsset asset,
    required VehicleAssetCatalogItem? item,
    int sortIndex = 0,
  }) {
    final now = DateTime.now().toUtc();
    return VehicleAssetCheckLine(
      id: const Uuid().v4(),
      checkId: checkId,
      tenantId: asset.tenantId,
      vehicleAssetId: asset.id,
      assetName: item?.name.trim().isNotEmpty == true
          ? item!.name.trim()
          : 'Unknown tool',
      partNumber: item?.partNumber?.trim() ?? '',
      serialNumber: asset.serialNumber?.trim() ?? '',
      // Carried forward, not reset. A tool that came back broken yesterday is
      // still broken this morning, and making the driver re-report it every day
      // is how a form starts getting signed without being read.
      readiness: asset.readiness,
      isMissing: asset.isMissing,
      sortIndex: sortIndex,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String checkId;
  final String tenantId;

  /// Null once the underlying tool is deleted. The snapshot columns are what
  /// keep the line readable after that.
  final String? vehicleAssetId;

  final String assetName;
  final String partNumber;
  final String serialNumber;
  final int quantity;
  final AssetReadiness readiness;
  final bool isMissing;
  final String reason;
  final int sortIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "IDEAL ½ EMT BENDER · 74-031" — the tool as the receipt prints it.
  String get displayLabel =>
      partNumber.isEmpty ? assetName : '$assetName · $partNumber';

  /// Anything that is not "present and working". These are the lines dispatch
  /// actually reads.
  bool get isException => isMissing || readiness == AssetReadiness.nmc;

  /// Why this line cannot be signed, or null when it is fine.
  ///
  /// Only "missing" is hard-blocked: a missing ladder with no explanation is
  /// the one combination on the form that tells nobody anything. An NMC tool
  /// without a reason is merely unhelpful, and the database agrees — its check
  /// constraint covers missing only.
  String? get problem {
    if (isMissing && reason.trim().isEmpty) {
      return '$assetName is marked missing — say why.';
    }
    return null;
  }

  VehicleAssetCheckLine copyWith({
    AssetReadiness? readiness,
    bool? isMissing,
    String? reason,
    int? quantity,
    DateTime? updatedAt,
  }) {
    return VehicleAssetCheckLine(
      id: id,
      checkId: checkId,
      tenantId: tenantId,
      vehicleAssetId: vehicleAssetId,
      assetName: assetName,
      partNumber: partNumber,
      serialNumber: serialNumber,
      quantity: quantity ?? this.quantity,
      readiness: readiness ?? this.readiness,
      isMissing: isMissing ?? this.isMissing,
      reason: reason ?? this.reason,
      sortIndex: sortIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}

/// A signed receipt for the tools in one vehicle, on one dispatch.
///
/// This is the digital version of the paper the driver signs every morning.
/// Dispatch does the data entry, the driver reads the disclaimer and signs, and
/// dispatch counter-signs as a second verification.
class VehicleAssetCheck {
  const VehicleAssetCheck({
    required this.id,
    required this.tenantId,
    required this.vehicleId,
    required this.checkedAt,
    required this.disclaimerVersion,
    required this.createdAt,
    required this.updatedAt,
    this.lines = const [],
    this.operatorUserId,
    this.operatorName = '',
    this.coOperatorName = '',
    this.dispatcherUserId,
    this.dispatcherName = '',
    this.operatorSignaturePath,
    this.operatorSignedAt,
    this.dispatcherSignaturePath,
    this.dispatcherSignedAt,
    this.disclaimerAcceptedAt,
    this.notes = '',
  });

  factory VehicleAssetCheck.newDraft({
    required String tenantId,
    required String vehicleId,
    required int disclaimerVersion,
  }) {
    final now = DateTime.now().toUtc();
    return VehicleAssetCheck(
      id: const Uuid().v4(),
      tenantId: tenantId,
      vehicleId: vehicleId,
      checkedAt: now,
      disclaimerVersion: disclaimerVersion,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String tenantId;
  final String vehicleId;
  final DateTime checkedAt;

  final List<VehicleAssetCheckLine> lines;

  /// The driver. The id links to an app user when there is one; the name is
  /// always kept, because a receipt that needs a database lookup to say who
  /// signed it is worse than the paper it replaces.
  final String? operatorUserId;
  final String operatorName;

  /// Often a helper with no app account, so this is a printed name only.
  final String coOperatorName;

  final String? dispatcherUserId;
  final String dispatcherName;

  final String? operatorSignaturePath;
  final DateTime? operatorSignedAt;
  final String? dispatcherSignaturePath;
  final DateTime? dispatcherSignedAt;

  /// Which wording was shown, and when it was accepted. Recorded apart from the
  /// signature because the modal is presented before the pen is offered.
  final int disclaimerVersion;
  final DateTime? disclaimerAcceptedAt;

  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSignedByOperator => operatorSignedAt != null;
  bool get isCounterSigned => dispatcherSignedAt != null;
  bool get disclaimerAccepted => disclaimerAcceptedAt != null;

  ReceiptStage get stage {
    if (isCounterSigned) return ReceiptStage.complete;
    if (isSignedByOperator) return ReceiptStage.awaitingCountersign;
    return ReceiptStage.draft;
  }

  int get missingCount => lines.where((l) => l.isMissing).length;
  int get exceptionCount => lines.where((l) => l.isException).length;
  bool get hasMissing => missingCount > 0;

  /// Lines dispatch needs to look at. Ordered as printed.
  List<VehicleAssetCheckLine> get exceptions =>
      lines.where((l) => l.isException).toList(growable: false)
        ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

  /// What stands between this receipt and the driver's signature.
  ///
  /// Returned as a list rather than a bool so the screen can say which line is
  /// wrong. An empty list means the pen can be offered.
  List<String> get problemsBeforeSigning {
    final problems = <String>[];

    if (lines.isEmpty) {
      problems.add('This vehicle has no tools assigned, so there is nothing '
          'to sign for.');
    }
    if (operatorName.trim().isEmpty) {
      problems.add('Enter the operator\'s name.');
    }
    for (final line in lines) {
      final problem = line.problem;
      if (problem != null) problems.add(problem);
    }
    if (!disclaimerAccepted) {
      problems.add('The operator has to read and accept the asset disclaimer.');
    }
    return problems;
  }

  /// What stands between this receipt and dispatch's counter-signature.
  List<String> get problemsBeforeCountersigning {
    final problems = <String>[];
    if (!isSignedByOperator) {
      problems.add('The operator has to sign before dispatch verifies it.');
    }
    if (dispatcherName.trim().isEmpty) {
      problems.add('Enter the dispatcher\'s name.');
    }
    return problems;
  }

  VehicleAssetCheck copyWith({
    DateTime? checkedAt,
    List<VehicleAssetCheckLine>? lines,
    String? operatorUserId,
    bool clearOperatorUserId = false,
    String? operatorName,
    String? coOperatorName,
    String? dispatcherUserId,
    bool clearDispatcherUserId = false,
    String? dispatcherName,
    String? operatorSignaturePath,
    DateTime? operatorSignedAt,
    bool clearOperatorSignature = false,
    String? dispatcherSignaturePath,
    DateTime? dispatcherSignedAt,
    bool clearDispatcherSignature = false,
    int? disclaimerVersion,
    DateTime? disclaimerAcceptedAt,
    bool clearDisclaimerAccepted = false,
    String? notes,
    DateTime? updatedAt,
  }) {
    return VehicleAssetCheck(
      id: id,
      tenantId: tenantId,
      vehicleId: vehicleId,
      checkedAt: checkedAt ?? this.checkedAt,
      lines: lines ?? this.lines,
      operatorUserId:
          clearOperatorUserId ? null : (operatorUserId ?? this.operatorUserId),
      operatorName: operatorName ?? this.operatorName,
      coOperatorName: coOperatorName ?? this.coOperatorName,
      dispatcherUserId: clearDispatcherUserId
          ? null
          : (dispatcherUserId ?? this.dispatcherUserId),
      dispatcherName: dispatcherName ?? this.dispatcherName,
      operatorSignaturePath: clearOperatorSignature
          ? null
          : (operatorSignaturePath ?? this.operatorSignaturePath),
      operatorSignedAt: clearOperatorSignature
          ? null
          : (operatorSignedAt ?? this.operatorSignedAt),
      dispatcherSignaturePath: clearDispatcherSignature
          ? null
          : (dispatcherSignaturePath ?? this.dispatcherSignaturePath),
      dispatcherSignedAt: clearDispatcherSignature
          ? null
          : (dispatcherSignedAt ?? this.dispatcherSignedAt),
      disclaimerVersion: disclaimerVersion ?? this.disclaimerVersion,
      disclaimerAcceptedAt: clearDisclaimerAccepted
          ? null
          : (disclaimerAcceptedAt ?? this.disclaimerAcceptedAt),
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Replace one line, keeping the rest in place.
  VehicleAssetCheck withLine(VehicleAssetCheckLine replacement) {
    return copyWith(
      lines: [
        for (final line in lines)
          if (line.id == replacement.id) replacement else line,
      ],
    );
  }
}
