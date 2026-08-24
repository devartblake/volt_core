import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/user_role.dart';

/// Simple DTO representing the authenticated user/session info
class AuthRemoteUser {
  final String userId;
  final String email;
  final String displayName;

  /// The role the session is acting as. Always one of [grantedRoles] when the
  /// server returned any — never a value chosen purely on the client.
  final UserRole role;

  /// Every role this user actually holds, per `tenant_members`. Drives the
  /// role switcher so it can only ever offer real grants.
  final Set<UserRole> grantedRoles;

  const AuthRemoteUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    this.grantedRoles = const {},
  });

  @override
  String toString() {
    return 'AuthRemoteUser(userId: $userId, email: $email, '
        'displayName: $displayName, role: $role, granted: $grantedRoles)';
  }
}

/// Low-level remote datasource for Auth using Supabase.
///
/// This is intentionally "dumb": it only knows how to talk to Supabase
/// and return small DTOs. Higher layers (repository/usecases) decide
/// how to interpret roles, etc.
class AuthRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthRemoteUser> loginWithEmailPassword({
    required String email,
    required String password,
    UserRole? preferredRole,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('No user returned from Supabase auth.');
    }

    final metadata = user.userMetadata ?? <String, dynamic>{};
    final fullName = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        _deriveDisplayName(email);

    final granted = await _fetchGrantedRoles(user);
    final effectiveRole = _resolveRole(
      granted: granted,
      preferredRole: preferredRole,
    );

    final result = AuthRemoteUser(
      userId: user.id,
      email: user.email ?? email,
      displayName: fullName,
      role: effectiveRole,
      grantedRoles: granted,
    );

    if (kDebugMode) {
      debugPrint('[AuthRemoteDataSource] loginWithEmailPassword → $result');
    }

    return result;
  }

  Future<void> changePassword(String newPassword) async {
    if (_client.auth.currentUser == null) {
      throw AuthException('No authenticated user is available.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Try to restore the current session from Supabase cache.
  /// Returns null if no session/user.
  Future<AuthRemoteUser?> getCurrentUser({UserRole? preferredRole}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final email = user.email ?? '';
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final fullName = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        _deriveDisplayName(email);

    final granted = await _fetchGrantedRoles(user);
    final effectiveRole = _resolveRole(
      granted: granted,
      preferredRole: preferredRole,
    );

    final result = AuthRemoteUser(
      userId: user.id,
      email: email,
      displayName: fullName,
      role: effectiveRole,
      grantedRoles: granted,
    );

    if (kDebugMode) {
      debugPrint('[AuthRemoteDataSource] getCurrentUser → $result');
    }

    return result;
  }

  Future<Set<UserRole>> _fetchGrantedRoles(User user) async {
    final roles = <UserRole>{};

    try {
      var query = _client
          .from('tenant_members')
          .select('role')
          .eq('user_id', user.id)
          .eq('is_active', true);

      final tenantId = SyncContext.tenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final rows = (await query) as List;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final role = UserRoleX.fromString(row['role']?.toString());
        if (role != null) roles.add(role);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthRemoteDataSource] tenant_members role lookup '
            'failed: $e');
      }
    }

    if (roles.isEmpty) {
      final claimed = _mapRole((user.appMetadata['role'] as String?)?.toLowerCase());
      if (claimed != null) roles.add(claimed);
    }

    return roles;
  }

  UserRole _resolveRole({
    required Set<UserRole> granted,
    UserRole? preferredRole,
  }) {
    if (granted.isEmpty) return UserRole.tech;
    if (preferredRole != null && granted.contains(preferredRole)) {
      return preferredRole;
    }
    return highestRole(granted) ?? UserRole.tech;
  }

  String _deriveDisplayName(String email) {
    if (email.isEmpty) return 'User';
    final base = email.split('@').first;
    if (base.isEmpty) return 'User';
    return base[0].toUpperCase() + base.substring(1);
  }

  UserRole? _mapRole(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'dispatcher':
        return UserRole.dispatcher;
      case 'tech':
      case 'technician':
        return UserRole.tech;
      default:
        return null;
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
