import 'package:flutter/material.dart';

import '../infra/models/maintenance_record.dart';

/// The eight steps of the maintenance form, in order.
enum MaintenanceStep {
  siteInfo('Site Information', Icons.location_on_outlined),
  walkthrough('Walkthrough', Icons.explore_outlined),
  general('General Maintenance', Icons.settings_outlined),
  actions('Actions Performed', Icons.build_outlined),
  postService('Post-Service', Icons.task_alt_outlined),
  parts('Parts & Materials', Icons.inventory_2_outlined),
  photos('Photos', Icons.photo_camera_outlined),
  signatures('Signatures', Icons.draw_outlined);

  const MaintenanceStep(this.title, this.icon);

  final String title;
  final IconData icon;

  /// Steps a finished record is expected to have. The rest are optional: a
  /// service with no parts used or no photos is still a complete record.
  bool get expected => this == siteInfo || this == signatures;
}

/// How far along a step is.
enum StepStatus {
  /// Nothing entered.
  empty('Not started'),

  /// Something entered, key details still missing.
  started('In progress'),

  /// Its key details are in.
  done('Done');

  const StepStatus(this.label);

  final String label;
}

bool _filled(String? s) => (s ?? '').trim().isNotEmpty;

/// Per-step progress for a maintenance record.
///
/// "Done" means the step's key details are present, not that the work was
/// good: it exists so a technician can see at a glance which parts of a long
/// form they have not touched. Nothing here blocks saving.
class MaintenanceProgress {
  const MaintenanceProgress(this.statuses);

  final Map<MaintenanceStep, StepStatus> statuses;

  StepStatus of(MaintenanceStep step) => statuses[step] ?? StepStatus.empty;

  int get doneCount =>
      statuses.values.where((s) => s == StepStatus.done).length;

  int get total => MaintenanceStep.values.length;

  /// 0..1 across all steps; a step in progress counts as half.
  double get fraction {
    var points = 0.0;
    for (final s in statuses.values) {
      points += switch (s) {
        StepStatus.done => 1,
        StepStatus.started => 0.5,
        StepStatus.empty => 0,
      };
    }
    return points / total;
  }

  /// Nothing has been entered anywhere.
  bool get isBlank => statuses.values.every((s) => s == StepStatus.empty);

  /// Expected steps that are not done yet.
  List<MaintenanceStep> get missingExpected => [
        for (final step in MaintenanceStep.values)
          if (step.expected && of(step) != StepStatus.done) step,
      ];

  factory MaintenanceProgress.compute(
    MaintenanceRecord m, {
    int photoCount = 0,
    int materialCount = 0,
  }) {
    StepStatus grade(Iterable<bool> keyDone, Iterable<bool> anyTouched) {
      final keys = keyDone.toList();
      if (keys.isNotEmpty && keys.every((k) => k)) return StepStatus.done;
      if (keys.any((k) => k) || anyTouched.any((t) => t)) {
        return StepStatus.started;
      }
      return StepStatus.empty;
    }

    // The service date starts filled in (today), so it counts toward "done"
    // but never makes an untouched record look started.
    final siteKeys = [
      _filled(m.address),
      _filled(m.technicianName),
      _filled(m.generatorMake),
      _filled(m.generatorModel),
      _filled(m.generatorSerial),
    ];
    final siteOptional = [
      _filled(m.siteCode),
      _filled(m.generatorKw),
      _filled(m.engineHours),
      _filled(m.fuelType),
      _filled(m.voltageRating),
    ];
    final siteInfo = siteKeys.every((k) => k) && m.dateOfService != null
        ? StepStatus.done
        : (siteKeys.any((k) => k) || siteOptional.any((o) => o)
            ? StepStatus.started
            : StepStatus.empty);

    final walkthrough = grade(
      [
        _filled(m.generatorLocation),
        m.enclosureDamaged || m.enclosureIntact || m.noEnclosure,
      ],
      [
        m.visibleDamageOrLeaks,
        m.areaClearOfHazards,
        m.warningLabelsVisible,
        m.fireExtinguisherPresent,
      ],
    );

    final general = grade(
      [_filled(m.coolantLevel), _filled(m.batteryType)],
      [
        m.batteryNeedsReplace,
        m.batteryRecentlyReplaced,
        m.airFilterNeedsReplace,
        m.airFilterRecentlyReplaced,
        _filled(m.coolantColor),
        m.coolantHosesCompromised,
        m.fuelHosesCompromised,
        m.airIntakeHosesCompromised,
        m.oilHosesCompromised,
        m.canLube,
        m.canFuel,
        m.canWaterSep,
        m.canOil,
      ],
    );

    final actionFlags = [
      m.oilFilterChanged,
      m.fuelFilterReplaced,
      m.coolantFlushed,
      m.batteryReplaced,
      m.airFilterReplaced,
      m.beltsHosesReplaced,
      m.blockHeaterTested,
      m.racorServiced,
      m.atsControllerInspected,
      m.cdvrProgrammed,
      m.undervoltageRepaired,
      m.hazmatRemoved,
    ];
    final actions = grade(
      [_filled(m.serviceObservations)],
      actionFlags,
    );

    final core = [
      m.postVerifyRunsUnderLoad,
      m.postCheckVoltFreq,
      m.postInspectExhaust,
      m.postVerifyGrounding,
      m.postCheckControlPanel,
      m.postEnsureSafetyDevices,
    ];
    final post = grade(core, [
      m.postDocumentDeficiencies,
      m.postLoadbankTest,
      m.postAtsFunctionality,
      m.fuelStoredLong,
    ]);

    final partsFields = [
      m.partsOilTypeQty,
      m.partsCoolantTypeQty,
      m.partsFilterTypes,
      m.partsBatteryTypeDate,
      m.partsBeltsHosesReplaced,
      m.partsBlockHeaterWattage,
      m.partsCdvrSerial,
    ];
    // Parts are optional, so any entry finishes the step: a listed material,
    // or text in the older free-text boxes.
    final parts = materialCount > 0 || partsFields.any(_filled)
        ? StepStatus.done
        : StepStatus.empty;

    final photos = photoCount > 0 ? StepStatus.done : StepStatus.empty;

    bool signed(String name, String? path) => _filled(name) || _filled(path);
    final tech = signed(m.technicianSignatureName, m.technicianSignaturePath);
    final cust = signed(m.customerSignatureName, m.customerSignaturePath);
    final signatures = tech && cust
        ? StepStatus.done
        : (tech || cust ? StepStatus.started : StepStatus.empty);

    return MaintenanceProgress({
      MaintenanceStep.siteInfo: siteInfo,
      MaintenanceStep.walkthrough: walkthrough,
      MaintenanceStep.general: general,
      MaintenanceStep.actions: actions,
      MaintenanceStep.postService: post,
      MaintenanceStep.parts: parts,
      MaintenanceStep.photos: photos,
      MaintenanceStep.signatures: signatures,
    });
  }
}
