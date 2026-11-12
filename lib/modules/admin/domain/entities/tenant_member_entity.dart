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
    this.divisionIds = const [],
  });

  final String tenantId;
  final String userId;
  final String displayName;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;

  /// The member's divisions (`public.member_divisions`; for a person with no
  /// rows there, the deprecated `tenant_members.division_id`). May be empty.
  final List<String> divisionIds;

  TenantMemberEntity copyWith({
    UserRole? role,
    bool? isActive,
    List<String>? divisionIds,
  }) {
    return TenantMemberEntity(
      tenantId: tenantId,
      userId: userId,
      displayName: displayName,
      email: email,
      phone: phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      divisionIds: divisionIds ?? this.divisionIds,
    );
  }
}
