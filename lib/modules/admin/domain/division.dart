/// A company-defined division (for example "Generators" or "Fire alarm").
///
/// Admins keep the list; every user may belong to one division, whatever their
/// role. Stored in `public.divisions`.
class Division {
  const Division({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  Division copyWith({String? name, int? sortOrder, bool? isActive}) => Division(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );

  /// Null when the row has no usable id or name.
  static Division? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    final order = json['sort_order'];
    return Division(
      id: id,
      name: name,
      sortOrder: order is num ? order.toInt() : int.tryParse('$order') ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Division &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(id, name, sortOrder, isActive);
}

const int kMaxDivisionName = 60;

/// Validation for a division name. [others] are the other divisions of the
/// company; names are unique ignoring case. Returns an error sentence or null.
String? validateDivisionName(String? value, Iterable<Division> others) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Enter a name.';
  if (name.length > kMaxDivisionName) {
    return 'Name must be $kMaxDivisionName characters or fewer.';
  }
  final lower = name.toLowerCase();
  if (others.any((d) => d.name.trim().toLowerCase() == lower)) {
    return 'A division with that name already exists.';
  }
  return null;
}

/// Divisions in the order admins arranged them (then by name).
List<Division> sortedDivisions(Iterable<Division> divisions) {
  final list = divisions.toList();
  list.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0
        ? byOrder
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

/// Name of the division with [id], or null when unset or unknown.
String? divisionNameOf(String? id, Iterable<Division> divisions) {
  if (id == null || id.isEmpty) return null;
  for (final d in divisions) {
    if (d.id == id) return d.name;
  }
  return null;
}
