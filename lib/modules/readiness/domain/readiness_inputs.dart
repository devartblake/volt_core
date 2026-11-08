/// Plain input records for `computeReadiness`. The providers map the app's
/// entities onto these, so the rules never import Hive or Flutter.
library;

/// A generator inspection (from `InspectionEntity`).
class ReadinessInspection {
  const ReadinessInspection({
    required this.id,
    required this.serviceDate,
    this.siteCode = '',
    this.address = '',
    this.grade = '',
    this.nextDueAt,
    this.make = '',
    this.model = '',
    this.serial = '',
    this.fuelType = '',
    this.loadbankDone = false,
    this.updatedAt,
  });

  final String id;
  final DateTime serviceDate;
  final String siteCode;
  final String address;

  /// "Green" | "Amber" | "Red" | '' (any case).
  final String grade;
  final DateTime? nextDueAt;
  final String make;
  final String model;
  final String serial;
  final String fuelType;

  /// The inspection's "load bank done" switch: the only load-test date the
  /// app records is this inspection's service date.
  final bool loadbankDone;
  final DateTime? updatedAt;
}

/// A maintenance record (from `MaintenanceRecord`).
class ReadinessMaintenance {
  const ReadinessMaintenance({
    required this.id,
    this.inspectionId,
    this.siteCode = '',
    this.address = '',
    this.make = '',
    this.model = '',
    this.serial = '',
    this.date,
    this.completed = false,
    this.requiresFollowUp = false,
    this.followUpNotes = '',
  });

  final String id;
  final String? inspectionId;
  final String siteCode;
  final String address;
  final String make;
  final String model;
  final String serial;

  /// Date of service, else when it was created.
  final DateTime? date;
  final bool completed;
  final bool requiresFollowUp;
  final String? followUpNotes;
}

/// A schedule task (from `TaskScheduleEntity`).
class ReadinessTask {
  const ReadinessTask({
    required this.id,
    required this.scheduledAt,
    this.siteCode = '',
    this.inspectionId,
    this.sourceType = '',
    this.sourceId,
    this.status = 'scheduled',
  });

  final String id;
  final DateTime scheduledAt;
  final String siteCode;
  final String? inspectionId;

  /// inspection | maintenance_record | work_order | manual | other
  final String sourceType;
  final String? sourceId;

  /// scheduled | in_progress | completed | cancelled
  final String status;

  bool get isOpen {
    final s = status.trim().toLowerCase();
    return s == 'scheduled' || s == 'in_progress' || s == 'in progress';
  }
}

/// An equipment registry row (from `EquipmentEntity`).
class ReadinessEquipment {
  const ReadinessEquipment({
    required this.id,
    this.make = '',
    this.model = '',
    this.serial = '',
    this.siteCode = '',
    this.location = '',
    this.fuelType = '',
    this.isGenerator = true,
    this.isRetired = false,
    this.lastInspection,
  });

  final String id;
  final String make;
  final String model;
  final String serial;
  final String siteCode;
  final String location;
  final String fuelType;

  /// Only generators become units.
  final bool isGenerator;
  final bool isRetired;
  final DateTime? lastInspection;
}

/// A site from the customer directory.
class ReadinessSite {
  const ReadinessSite({
    required this.siteCode,
    this.address = '',
    this.customerName = '',
  });

  final String siteCode;
  final String address;
  final String customerName;
}

enum ReadinessJobType { inspection, maintenance }

/// A job whose parts needs are short (from `JobNeeds` with `shortCount > 0`).
class ReadinessJobNeed {
  const ReadinessJobNeed({
    required this.type,
    required this.jobId,
    required this.shortCount,
  });

  final ReadinessJobType type;
  final String jobId;
  final int shortCount;
}

/// Everything `computeReadiness` reads. Every list may be empty.
class ReadinessInputs {
  const ReadinessInputs({
    this.inspections = const [],
    this.maintenance = const [],
    this.tasks = const [],
    this.equipment = const [],
    this.sites = const [],
    this.jobNeeds = const [],
  });

  final List<ReadinessInspection> inspections;
  final List<ReadinessMaintenance> maintenance;
  final List<ReadinessTask> tasks;
  final List<ReadinessEquipment> equipment;
  final List<ReadinessSite> sites;
  final List<ReadinessJobNeed> jobNeeds;
}

/// Records that could not be tied to exactly one unit. They are never guessed
/// at and never create a unit; the counts let a screen say "3 records could
/// not be matched".
class ReadinessUnmatched {
  const ReadinessUnmatched({
    this.maintenance = 0,
    this.tasks = 0,
    this.jobNeeds = 0,
    this.skippedEquipment = 0,
  });

  final int maintenance;
  final int tasks;
  final int jobNeeds;

  /// Equipment rows left out because they were retired or not generators.
  final int skippedEquipment;

  int get total => maintenance + tasks + jobNeeds;
}
