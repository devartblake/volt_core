import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase/supabase_service.dart';
import '../../domain/user_role.dart';

/// Simple DTO representing the authenticated user/session info
class AuthRemoteUser {
  final String userId;
  final String email;
  final String displayName;
  final UserRole role;

  const AuthRemoteUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
  });

  @override
  String toString() {
    return 'AuthRemoteUser(userId: $userId, email: $email, displayName: $displayName, role: $role)';
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

    // Try to derive display name from metadata or email.
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final fullName = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        _deriveDisplayName(email);

    // Role derivation strategy:
    // - If a preferredRole is provided (e.g. from UI role selector), we use it.
    // - Otherwise, you can inspect user.appMetadata['role'] or default to tech.
    final appMeta = user.appMetadata ?? <String, dynamic>{};
    final remoteRoleString = (appMeta['role'] as String?)?.toLowerCase();
    final remoteRole = _mapRole(remoteRoleString);

    final effectiveRole = preferredRole ?? remoteRole ?? UserRole.tech;

    final result = AuthRemoteUser(
      userId: user.id,
      email: user.email ?? email,
      displayName: fullName,
      role: effectiveRole,
    );

    if (kDebugMode) {
      debugPrint('[AuthRemoteDataSource] loginWithEmailPassword → $result');
    }

    return result;
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

    final appMeta = user.appMetadata ?? <String, dynamic>{};
    final remoteRoleString = (appMeta['role'] as String?)?.toLowerCase();
    final remoteRole = _mapRole(remoteRoleString);
    final effectiveRole = preferredRole ?? remoteRole ?? UserRole.tech;

    final result = AuthRemoteUser(
      userId: user.id,
      email: email,
      displayName: fullName,
      role: effectiveRole,
    );

    if (kDebugMode) {
      debugPrint('[AuthRemoteDataSource] getCurrentUser → $result');
    }

    return result;
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
