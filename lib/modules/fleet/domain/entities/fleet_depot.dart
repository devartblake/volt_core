import 'package:uuid/uuid.dart';

/// A yard the company's vehicles live in.
///
/// **Not a `site`.** In this codebase a site is a *customer's* service location
/// — where work is performed — and inspections, work orders and form responses
/// all use `site_id` with that meaning. A depot is the other end of the
/// journey: premises the tenant owns. Sharing the column would put A&S's own
/// garage in the customer list.
class FleetDepot {
  const FleetDepot({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.address = '',
    this.notes = '',
    this.isActive = true,
  });

  factory FleetDepot.newDraft({required String tenantId}) {
    final now = DateTime.now().toUtc();
    return FleetDepot(
      id: const Uuid().v4(),
      tenantId: tenantId,
      name: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String tenantId;
  final String name;
  final String address;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FleetDepot copyWith({
    String? name,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return FleetDepot(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}
