/// Groups raw records into units. See docs/fleet_readiness.md, "Join rules".
///
/// Identity of a unit, in order:
///  1. a known serial number (case/space-insensitive; "n/a", "none", "-" and
///     similar placeholders count as unknown),
///  2. otherwise the site code,
///  3. otherwise the record itself (a unit of one).
///
/// Records that are not inspections never create a unit (except registry
/// equipment that has not been inspected yet). A record that matches no unit,
/// or matches several, is counted in [ReadinessUnmatched] and ignored.
library;

import 'readiness_inputs.dart';

/// Placeholder text techs type when there is no serial.
const _noSerial = {
  '',
  '-',
  '--',
  'n/a',
  'na',
  'none',
  'unknown',
  'unk',
  'tbd',
  'not available',
  'not visible',
  'illegible',
};

String normText(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Normalised serial, or '' when blank or a placeholder.
String normSerial(String s) {
  final n = normText(s);
  return _noSerial.contains(n) ? '' : n;
}

/// Normalised site code, or ''.
String normSite(String s) => normText(s);

/// Local calendar date at midnight.
DateTime dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Whole calendar days from [from] to [to] (negative if [to] is earlier),
/// unaffected by daylight-saving changes.
int daysBetween(DateTime from, DateTime to) {
  final a = dayOf(from), b = dayOf(to);
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

/// "Queens" for `Q_...`, "Bronx" for `X_...` (case-insensitive), else ''.
/// Only these two prefixes are known (they come from the tracker sheet names);
/// any other code gives no borough rather than a guess.
String boroughOfSiteCode(String siteCode) {
  final c = siteCode.trim().toUpperCase();
  if (c.startsWith('Q_')) return 'Queens';
  if (c.startsWith('X_')) return 'Bronx';
  return '';
}

/// A unit while it is being assembled.
class JoinedUnit {
  JoinedUnit();

  /// Normalised serial; '' for site-level units.
  String serialN = '';

  /// Normalised site code for a site-level unit (no serial).
  String siteKeyN = '';

  /// Set for a unit of one that has neither serial nor site.
  String loneId = '';
  bool retired = false;

  /// Oldest first.
  final inspections = <ReadinessInspection>[];
  final maintenance = <ReadinessMaintenance>[];
  final tasks = <ReadinessTask>[];
  final equipment = <ReadinessEquipment>[];
  final jobNeeds = <ReadinessJobNeed>[];

  /// Every normalised site code this unit has been seen at.
  final sites = <String>{};
}

class JoinResult {
  JoinResult(this.units, this.unmatched, this.inspectionUnit);

  final List<JoinedUnit> units;
  final ReadinessUnmatched unmatched;

  /// Inspection id -> its unit.
  final Map<String, JoinedUnit> inspectionUnit;
}

/// Joins [inputs] into units. Deterministic: ties are broken by id.
JoinResult joinUnits(ReadinessInputs inputs) {
  final units = <JoinedUnit>[];
  final bySerial = <String, JoinedUnit>{};
  final bySiteOnly = <String, JoinedUnit>{};
  final bySite = <String, List<JoinedUnit>>{};
  final byInspection = <String, JoinedUnit>{};
  final byMaintenance = <String, JoinedUnit>{};

  void register(JoinedUnit u, String siteN) {
    if (siteN.isEmpty) return;
    if (u.sites.add(siteN)) (bySite[siteN] ??= []).add(u);
  }

  JoinedUnit serialUnit(String sn) => bySerial.putIfAbsent(sn, () {
        final u = JoinedUnit()..serialN = sn;
        units.add(u);
        return u;
      });

  JoinedUnit siteUnit(String siteN, String fallbackId) {
    if (siteN.isEmpty) {
      final u = JoinedUnit()..loneId = fallbackId;
      units.add(u);
      return u;
    }
    return bySiteOnly.putIfAbsent(siteN, () {
      final u = JoinedUnit()..siteKeyN = siteN;
      units.add(u);
      register(u, siteN);
      return u;
    });
  }

  /// The one unit a record belongs to, or null (no match or ambiguous).
  JoinedUnit? resolve(String serial, String site, String make, String model) {
    final sn = normSerial(serial);
    if (sn.isNotEmpty) return bySerial[sn]; // a different serial never falls back
    final siteN = normSite(site);
    if (siteN.isEmpty) return null;
    final mk = normText(make), md = normText(model);
    final cands = [
      for (final c in bySite[siteN] ?? const <JoinedUnit>[])
        if (_makeModelAgree(c, mk, md)) c,
    ];
    return cands.length == 1 ? cands.first : null;
  }

  // 1. Inspections, oldest first; serial-bearing ones create units first.
  final inspections = [...inputs.inspections]..sort(_byDateThenId);
  final noSerial = <ReadinessInspection>[];
  for (final i in inspections) {
    final sn = normSerial(i.serial);
    if (sn.isEmpty) {
      noSerial.add(i);
      continue;
    }
    final u = serialUnit(sn)..inspections.add(i);
    register(u, normSite(i.siteCode));
    byInspection[i.id] = u;
  }
  for (final i in noSerial) {
    final u = resolve('', i.siteCode, i.make, i.model) ??
        siteUnit(normSite(i.siteCode), i.id);
    u.inspections.add(i);
    register(u, normSite(i.siteCode));
    byInspection[i.id] = u;
  }

  // 2. Registry equipment: joins a unit, else becomes one (this is how a
  // registered but never inspected generator shows up).
  var skipped = 0;
  final equipment = [...inputs.equipment]..sort((a, b) => a.id.compareTo(b.id));
  for (final e in equipment) {
    if (!e.isGenerator) {
      skipped++;
      continue;
    }
    final sn = normSerial(e.serial);
    final u = resolve(e.serial, e.siteCode, e.make, e.model) ??
        (sn.isNotEmpty
            ? serialUnit(sn)
            : siteUnit(normSite(e.siteCode), 'eq:${e.id}'));
    u.equipment.add(e);
    register(u, normSite(e.siteCode));
  }
  // A unit is retired when it has registry rows and all of them are retired.
  for (final u in units) {
    u.retired = u.equipment.isNotEmpty && u.equipment.every((e) => e.isRetired);
  }

  // 3. Maintenance (inspection link first, then serial / site).
  var unMaint = 0, unTask = 0, unJob = 0;
  final maintenance = [...inputs.maintenance]..sort((a, b) {
      final c = _cmpDate(a.date, b.date);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  for (final m in maintenance) {
    final iid = m.inspectionId;
    final u = (iid == null || iid.isEmpty ? null : byInspection[iid]) ??
        resolve(m.serial, m.siteCode, m.make, m.model);
    if (u == null) {
      unMaint++;
      continue;
    }
    u.maintenance.add(m);
    byMaintenance[m.id] = u;
  }

  // 4. Schedule tasks (links first, then site code only: tasks carry no
  // serial).
  final tasks = [...inputs.tasks]..sort((a, b) {
      final c = a.scheduledAt.compareTo(b.scheduledAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  for (final t in tasks) {
    final iid = t.inspectionId ?? (t.sourceType == 'inspection' ? t.sourceId : null);
    JoinedUnit? u = (iid == null || iid.isEmpty) ? null : byInspection[iid];
    if (u == null && t.sourceType == 'maintenance_record' && t.sourceId != null) {
      u = byMaintenance[t.sourceId];
    }
    u ??= resolve('', t.siteCode, '', '');
    if (u == null) {
      unTask++;
      continue;
    }
    u.tasks.add(t);
  }

  // 5. Short parts, through the job they belong to.
  for (final j in inputs.jobNeeds) {
    final u = j.type == ReadinessJobType.inspection
        ? byInspection[j.jobId]
        : byMaintenance[j.jobId];
    if (u == null) {
      unJob++;
      continue;
    }
    u.jobNeeds.add(j);
  }

  return JoinResult(
    units,
    ReadinessUnmatched(
      maintenance: unMaint,
      tasks: unTask,
      jobNeeds: unJob,
      skippedEquipment: skipped,
    ),
    byInspection,
  );
}

/// A record naming a make/model only joins a unit whose known make/model do
/// not contradict it. Blank on either side is "no evidence against".
bool _makeModelAgree(JoinedUnit u, String mk, String md) {
  String umk = '', umd = '';
  if (u.inspections.isNotEmpty) {
    umk = normText(u.inspections.last.make);
    umd = normText(u.inspections.last.model);
  } else if (u.equipment.isNotEmpty) {
    umk = normText(u.equipment.first.make);
    umd = normText(u.equipment.first.model);
  }
  if (mk.isNotEmpty && umk.isNotEmpty && mk != umk) return false;
  if (md.isNotEmpty && umd.isNotEmpty && md != umd) return false;
  return true;
}

int _cmpDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

int _byDateThenId(ReadinessInspection a, ReadinessInspection b) {
  final c = a.serviceDate.compareTo(b.serviceDate);
  if (c != 0) return c;
  final u = _cmpDate(a.updatedAt, b.updatedAt);
  return u != 0 ? u : a.id.compareTo(b.id);
}
