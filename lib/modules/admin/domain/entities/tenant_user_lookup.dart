import '../../../auth/domain/user_role.dart';

/// A registered account found by email, and its standing in the active tenant.
///
/// Distinct from `TenantMemberEntity`: this describes somebody who may not be a
/// member at all. [isMember] is what separates "no such account" (null lookup
/// result) from "already on the team" — different problems with different
/// fixes, and an admin who cannot tell them apart will go looking in the wrong
/// place.
class TenantUserLookup {
  const TenantUserLookup({
    required this.tenantId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.isActiveAccount,
    required this.isMember,
    this.phone,
    this.currentRole,
  });

  final String tenantId;
  final String userId;
  final String displayName;
  final String email;
  final String? phone;

  /// Whether the *account* is enabled, independent of tenant membership.
  final bool isActiveAccount;

  /// Whether they already hold a membership row in this tenant.
  final bool isMember;

  /// Their role in this tenant, when [isMember].
  final UserRole? currentRole;
}
