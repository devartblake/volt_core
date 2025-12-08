import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

class TechnicianModel extends TechnicianEntity {
  const TechnicianModel({
    required super.id,
    required super.name,
    required super.role,
    super.email,
    super.phone,
    super.isActive = true,
    super.lastActivityAt,
    super.createdAt,
    super.updatedAt,
  });

  /// Existing factory used in older code.
  factory TechnicianModel.fromMap(Map<String, dynamic> map) {
    // Adjust keys to match your Supabase table structure
    final roleStr = (map['role'] as String?) ?? 'tech';

    return TechnicianModel(
      id: map['id'].toString(),
      name: (map['name'] as String?) ?? 'Unknown',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: _userRoleFromString(roleStr),
      isActive: (map['is_active'] as bool?) ?? true,
      lastActivityAt: _parseDate(map['last_activity_at']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  /// NEW: Alias so code that expects `fromJson` works.
  factory TechnicianModel.fromJson(Map<String, dynamic> json) {
    return TechnicianModel.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name, // see enum extension below
      'is_active': isActive,
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static UserRole _userRoleFromString(String value) {
    switch (value) {
      case 'tech':
        return UserRole.tech;
      case 'supervisor':
        return UserRole.supervisor;
      case 'dispatcher':
        return UserRole.dispatcher;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.tech;
    }
  }
}
