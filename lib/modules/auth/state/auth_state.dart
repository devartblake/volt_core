import 'package:flutter/foundation.dart';
import '../domain/user_role.dart';

/// Immutable auth state used across the app.
///
/// This is the single source of truth for:
/// - Whether the user is logged in (`isAuthenticated`)
/// - The current role (`currentRole`), used by RBAC / route guards
/// - Basic profile info (userId, email, displayName)
@immutable
class AuthState {
  final bool isAuthenticated;
  final UserRole? currentRole;
  final String? userId;
  final String? email;
  final String? displayName;

  const AuthState({
    required this.isAuthenticated,
    this.currentRole,
    this.userId,
    this.email,
    this.displayName,
  });

  /// Convenience unauthenticated state.
  const AuthState.unauthenticated()
      : isAuthenticated = false,
        currentRole = null,
        userId = null,
        email = null,
        displayName = null;

  AuthState copyWith({
    bool? isAuthenticated,
    UserRole? currentRole,
    String? userId,
    String? email,
    String? displayName,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentRole: currentRole ?? this.currentRole,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  /// Optional: a quick flag that some UIs can use
  bool get isAdmin => currentRole == UserRole.admin;

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, '
        'currentRole: $currentRole, userId: $userId, email: $email, '
        'displayName: $displayName)';
  }
}