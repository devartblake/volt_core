import 'package:voltcore/modules/auth/domain/user_role.dart';

/// Pure domain entity representing a technician / user that can have roles
/// like tech, supervisor, dispatcher, admin, etc.
class TechnicianEntity {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TechnicianEntity({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.isActive = true,
    this.lastActivityAt,
    this.createdAt,
    this.updatedAt,
  });

  TechnicianEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? isActive,
    DateTime? lastActivityAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TechnicianEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
