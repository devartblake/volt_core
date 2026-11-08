/// THE readiness rules. Everything that decides a unit's status is in this
/// file; change it here and nowhere else (and update docs/fleet_readiness.md).
///
/// Definitions (all dates are local calendar days; `today` = [now]'s day):
///
///  * latest inspection: the unit's newest inspection whose service date is
///    not after [now] (future-dated rows are planned visits, not history).
///  * lastGrade: the grade of the newest inspection that HAS a Green / Amber /
///    Red grade. A later Green therefore clears an earlier Red; a later
///    ungraded inspection does not.
///  * nextDueAt: the latest inspection's own `nextDueAt`; when it has none,
///    latest inspection date + `staleInspectionDays` (flagged as estimated).
///  * daysToDue: whole days from today to nextDueAt. Negative = overdue.
///  * open follow-up: a maintenance record with requiresFollowUp, unless the
///    unit has a completed maintenance record dated on a LATER day.
///  * partsShortCount: short lines on the latest inspection's parts list plus
///    all open (not completed) maintenance jobs of the unit.
///
/// Status table, first row that matches wins, top to bottom:
///
/// | Status    | When                                                          |
/// |-----------|---------------------------------------------------------------|
/// | notReady  | never inspected                                               |
/// | notReady  | lastGrade is Red (no later Green)                             |
/// | notReady  | overdue by MORE than criticalOverdueDays (default 30)         |
/// | attention | lastGrade is Amber                                            |
/// | attention | overdue by 1..criticalOverdueDays days (30 itself is here)    |
/// | attention | one or more open follow-ups                                   |
/// | attention | one or more short parts for its next job                      |
/// | dueSoon   | due in 0..dueSoonDays days (default 30; due today counts)     |
/// | ready     | everything else                                               |
///
/// The profile key below mirrors `generatorProfileKey` (materials module); a
/// test keeps the two identical.
///
/// Not part of the status (shown as info reasons only): a scheduled visit,
/// a missed scheduled visit, an estimated due date, load test dates.
library;

import 'readiness_inputs.dart';
import 'readiness_join.dart';
import 'readiness_models.dart';

/// The result of [computeReadiness].
class ReadinessReport {
  const ReadinessReport({
    required this.units,
    required this.unmatched,
    required this.now,
    required this.config,
  });

  /// Retired units are left out. Order: worst first (see `sortUnits`).
  final List<ReadinessUnit> units;
  final ReadinessUnmatched unmatched;

  /// The instant everything was computed against.
  final DateTime now;
  final ReadinessConfig config;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "3 Oct", or "3 Oct 2025" when not in [now]'s year.
String readinessDate(DateTime d, DateTime now) {
  final l = d.toLocal();
  final s = '${l.day} ${_months[l.month - 1]}';
  return l.year == now.toLocal().year ? s : '$s ${l.year}';
}

String _plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// Computes every unit's readiness from [inputs]. Pure and deterministic for a
/// given [now].
ReadinessReport computeReadiness(
  ReadinessInputs inputs,
  ReadinessConfig config,
  DateTime now,
) {
  final joined = joinUnits(inputs);
  final sites = <String, ReadinessSite>{};
  for (final s in inputs.sites) {
    final k = normSite(s.siteCode);
    if (k.isNotEmpty) sites.putIfAbsent(k, () => s);
  }

  final units = <ReadinessUnit>[];
  for (final j in joined.units) {
    if (j.retired) continue;
    units.add(_build(j, sites, config, now));
  }
  units.sort(compareWorstFirst);
  return ReadinessReport(
    units: List.unmodifiable(units),
    unmatched: joined.unmatched,
    now: now,
    config: config,
  );
}

/// Worst status first, then most overdue first, then title, then key. A total
/// order, so the result never depends on input order.
int compareWorstFirst(ReadinessUnit a, ReadinessUnit b) {
  final s = a.status.rank.compareTo(b.status.rank);
  if (s != 0) return s;
  final da = a.daysToDue, db = b.daysToDue;
  if (da != null && db != null) {
    final c = da.compareTo(db);
    if (c != 0) return c;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return t != 0 ? t : a.key.compareTo(b.key);
}

ReadinessUnit _build(
  JoinedUnit j,
  Map<String, ReadinessSite> sites,
  ReadinessConfig config,
  DateTime now,
) {
  final today = dayOf(now);

  // History = inspections that have happened.
  final past = [
    for (final i in j.inspections)
      if (!i.serviceDate.isAfter(now)) i,
  ];
  final latest = past.isEmpty ? null : past.last;
  final anyInsp = j.inspections.isEmpty ? null : j.inspections.last;
  final eq = j.equipment.isEmpty ? null : j.equipment.first;

  // Identity and descriptive fields: newest inspection that has the value.
  String pick(String Function(ReadinessInspection) f, String Function(ReadinessEquipment) g) {
    for (var n = j.inspections.length - 1; n >= 0; n--) {
      final v = f(j.inspections[n]).trim();
      if (v.isNotEmpty) return v;
    }
    for (final e in j.equipment) {
      final v = g(e).trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  final make = pick((i) => i.make, (e) => e.make);
  final model = pick((i) => i.model, (e) => e.model);
  var serial = pick((i) => normSerial(i.serial).isEmpty ? '' : i.serial,
      (e) => normSerial(e.serial).isEmpty ? '' : e.serial);
  if (j.serialN.isEmpty) serial = '';
  final siteCode = pick((i) => i.siteCode, (e) => e.siteCode);
  final dir = sites[normSite(siteCode)];
  var address = pick((i) => i.address, (e) => e.location);
  if (address.isEmpty && dir != null) address = dir.address.trim();
  final fuel = pick((i) => i.fuelType, (e) => e.fuelType);

  final profileKey = _profileKey(make, model, serial);
  final key = j.serialN.isNotEmpty && profileKey.isNotEmpty
      ? profileKey
      : j.siteKeyN.isNotEmpty
          ? 'site:${j.siteKeyN}'
          : j.serialN.isNotEmpty
              ? 'sn:${j.serialN}'
              : 'id:${j.loneId}';

  final makeModel = '$make $model'.trim();
  final title = makeModel.isNotEmpty
      ? makeModel
      : siteCode.isNotEmpty
          ? siteCode
          : address.isNotEmpty
              ? address
              : 'Unknown unit';

  // Last inspection, grade, due date.
  final lastInspectionAt = latest?.serviceDate ?? eq?.lastInspection;
  ReadinessInspection? graded;
  for (var n = past.length - 1; n >= 0; n--) {
    if (ReadinessGrade.parse(past[n].grade) != ReadinessGrade.none) {
      graded = past[n];
      break;
    }
  }
  final lastGrade =
      graded == null ? ReadinessGrade.none : ReadinessGrade.parse(graded.grade);

  DateTime? nextDueAt;
  var estimated = false;
  if (latest?.nextDueAt != null) {
    nextDueAt = latest!.nextDueAt;
  } else if (lastInspectionAt != null) {
    // Calendar arithmetic (not Duration) so daylight saving cannot shift it.
    final b = dayOf(lastInspectionAt);
    nextDueAt = DateTime(b.year, b.month, b.day + config.staleInspectionDays);
    estimated = true;
  }
  final daysToDue = nextDueAt == null ? null : daysBetween(today, nextDueAt);

  // Follow-ups.
  DateTime? lastCompletedMaint;
  for (final m in j.maintenance) {
    if (m.completed && m.date != null) {
      final d = dayOf(m.date!);
      if (lastCompletedMaint == null || d.isAfter(lastCompletedMaint)) {
        lastCompletedMaint = d;
      }
    }
  }
  final followUps = <ReadinessFollowUp>[];
  for (final m in j.maintenance) {
    if (!m.requiresFollowUp) continue;
    if (lastCompletedMaint != null &&
        m.date != null &&
        lastCompletedMaint.isAfter(dayOf(m.date!))) {
      continue; // resolved by a later completed visit
    }
    final text = (m.followUpNotes ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    final note = text.isEmpty
        ? 'Follow-up needed'
        : text.length <= 80
            ? text
            : '${text.substring(0, 79)}…';
    followUps.add(ReadinessFollowUp(sourceId: m.id, note: note, date: m.date));
  }

  // Load tests: the newest inspection with the load bank switch on.
  DateTime? lastLoad;
  for (final i in past) {
    if (i.loadbankDone) lastLoad = i.serviceDate;
  }
  final nextLoad = lastLoad == null
      ? null
      : DateTime(dayOf(lastLoad).year, dayOf(lastLoad).month,
          dayOf(lastLoad).day + config.loadTestIntervalDays);

  // Schedule.
  DateTime? nextTask;
  DateTime? missedTask;
  for (final t in j.tasks) {
    if (!t.isOpen) continue;
    final d = dayOf(t.scheduledAt);
    if (d.isBefore(today)) {
      if (missedTask == null || d.isAfter(missedTask)) missedTask = d;
    } else if (nextTask == null || t.scheduledAt.isBefore(nextTask)) {
      nextTask = t.scheduledAt;
    }
  }
  // Planned (future-dated) inspections count as scheduled visits too.
  for (final i in j.inspections) {
    if (i.serviceDate.isAfter(now) &&
        (nextTask == null || i.serviceDate.isBefore(nextTask))) {
      nextTask = i.serviceDate;
    }
  }

  // Parts: latest inspection's list + open maintenance jobs.
  final openMaint = {
    for (final m in j.maintenance)
      if (!m.completed) m.id,
  };
  var short = 0;
  for (final n in j.jobNeeds) {
    if (n.shortCount <= 0) continue;
    if (n.type == ReadinessJobType.inspection) {
      if (anyInsp != null && n.jobId == (latest ?? anyInsp).id) {
        short += n.shortCount;
      }
    } else if (openMaint.contains(n.jobId)) {
      short += n.shortCount;
    }
  }

  // Status and reasons.
  final reasons = <ReadinessReason>[];
  var status = ReadinessStatus.ready;
  void raise(ReadinessStatus s) {
    if (s.rank < status.rank) status = s;
  }

  if (lastInspectionAt == null) {
    raise(ReadinessStatus.notReady);
    reasons.add(const ReadinessReason(ReadinessReasonKind.neverInspected,
        ReadinessSeverity.critical, 'No inspection on record'));
  }
  if (graded != null && lastGrade == ReadinessGrade.red) {
    raise(ReadinessStatus.notReady);
    reasons.add(ReadinessReason(
        ReadinessReasonKind.redGrade,
        ReadinessSeverity.critical,
        '${_gradePhrase(graded, latest)} was Red (${readinessDate(graded.serviceDate, now)})'));
  } else if (graded != null && lastGrade == ReadinessGrade.amber) {
    raise(ReadinessStatus.attention);
    reasons.add(ReadinessReason(
        ReadinessReasonKind.amberGrade,
        ReadinessSeverity.warning,
        '${_gradePhrase(graded, latest)} was Amber (${readinessDate(graded.serviceDate, now)})'));
  }
  if (daysToDue != null) {
    if (daysToDue < 0) {
      final over = -daysToDue;
      final critical = over > config.criticalOverdueDays;
      raise(critical ? ReadinessStatus.notReady : ReadinessStatus.attention);
      reasons.add(ReadinessReason(
          ReadinessReasonKind.overdue,
          critical ? ReadinessSeverity.critical : ReadinessSeverity.warning,
          'Inspection overdue by ${_plural(over, 'day', 'days')}'));
    } else if (daysToDue <= config.dueSoonDays) {
      raise(ReadinessStatus.dueSoon);
      reasons.add(ReadinessReason(
          ReadinessReasonKind.dueSoon,
          ReadinessSeverity.info,
          daysToDue == 0
              ? 'Due today'
              : daysToDue == 1
                  ? 'Due tomorrow'
                  : 'Due in $daysToDue days'));
    }
    if (estimated) {
      reasons.add(ReadinessReason(
          ReadinessReasonKind.estimatedDueDate,
          ReadinessSeverity.info,
          'No next-due date set; counted ${config.staleInspectionDays} days from the last inspection'));
    }
  }
  if (followUps.isNotEmpty) {
    raise(ReadinessStatus.attention);
    reasons.add(ReadinessReason(
        ReadinessReasonKind.followUps,
        ReadinessSeverity.warning,
        followUps.length == 1
            ? '1 open follow-up'
            : '${followUps.length} open follow-ups'));
  }
  if (short > 0) {
    raise(ReadinessStatus.attention);
    reasons.add(ReadinessReason(
        ReadinessReasonKind.partsShort,
        ReadinessSeverity.warning,
        short == 1
            ? 'Parts short for next job (1 part)'
            : 'Parts short for next job ($short parts)'));
  }
  if (nextTask != null) {
    reasons.add(ReadinessReason(ReadinessReasonKind.visitScheduled,
        ReadinessSeverity.info, 'Visit scheduled ${readinessDate(nextTask, now)}'));
  } else if (missedTask != null) {
    reasons.add(ReadinessReason(ReadinessReasonKind.visitMissed,
        ReadinessSeverity.info,
        'Scheduled visit missed (${readinessDate(missedTask, now)})'));
  }

  // Worst first; stable within a severity (insertion order).
  final ordered = [
    for (final sev in ReadinessSeverity.values.reversed)
      for (final r in reasons)
        if (r.severity == sev) r,
  ];

  return ReadinessUnit(
    key: key,
    title: title,
    profileKey: profileKey,
    siteCode: siteCode,
    address: address,
    customer: dir?.customerName.trim() ?? '',
    borough: boroughOfSiteCode(siteCode),
    make: make,
    model: model,
    serial: serial,
    fuelType: fuel,
    lastInspectionAt: lastInspectionAt,
    lastGrade: lastGrade,
    lastGradeAt: graded?.serviceDate,
    nextDueAt: nextDueAt,
    dueIsEstimated: estimated,
    daysToDue: daysToDue,
    openFollowUps: List.unmodifiable(followUps),
    lastLoadTestAt: lastLoad,
    nextLoadTestDueAt: nextLoad,
    scheduledTaskNext: nextTask,
    partsShortCount: short,
    status: status,
    reasons: List.unmodifiable(ordered),
    latestInspectionId: latest?.id,
  );
}

String _gradePhrase(ReadinessInspection graded, ReadinessInspection? latest) =>
    identical(graded, latest) ? 'Last inspection' : 'Last graded inspection';

String _profileKey(String make, String model, String serial) {
  String norm(String s) =>
      s.toLowerCase().replaceAll('|', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final m = norm(make), mo = norm(model), sn = norm(serial);
  if (sn.isEmpty && (m.isEmpty || mo.isEmpty)) return '';
  return '$m|$mo|$sn';
}
