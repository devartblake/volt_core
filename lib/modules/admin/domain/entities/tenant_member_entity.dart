import '../../../auth/domain/user_role.dart';

class TenantMemberEntity {
  const TenantMemberEntity({
    required this.tenantId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.divisionId,
  });

  final String tenantId;
  final String userId;
  final String displayName;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;

  /// The member's division (`tenant_members.division_id`), if any.
  final String? divisionId;

  TenantMemberEntity copyWith({
    UserRole? role,
    bool? isActive,
    String? divisionId,
    bool clearDivision = false,
  }) {
    return TenantMemberEntity(
      tenantId: tenantId,
      userId: userId,
      displayName: displayName,
      email: email,
      phone: phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      divisionId: clearDivision ? null : (divisionId ?? this.divisionId),
    );
  }
}
