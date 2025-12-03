import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// App-wide roles used for RBAC.
/// Keep in sync with your route_roles.dart.
enum UserRole {
  tech,
  supervisor,
  dispatcher,
  admin,
}

/// Immutable auth state
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

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, '
        'currentRole: $currentRole, userId: $userId, email: $email, '
        'displayName: $displayName)';
  }
}

/// Controller (StateNotifier) for AuthState
class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState.unauthenticated());

  /// Simple login method for local RBAC demo.
  ///
  /// In a real backend-connected app, this would call your API
  /// and populate userId/email/role from the server.
  void login({
    required UserRole role,
    required String email,
    String? userId,
    String? displayName,
  }) {
    final derivedUserId = userId ?? _deriveUserId(email);
    state = AuthState(
      isAuthenticated: true,
      currentRole: role,
      userId: derivedUserId,
      email: email,
      displayName: displayName ?? _deriveDisplayName(email),
    );
    debugPrint('AuthController.login → $state');
  }

  /// Switch role for the currently logged-in user
  void switchRole(UserRole role) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(currentRole: role);
    debugPrint('AuthController.switchRole → $state');
  }

  /// Logout / clear auth
  void logout() {
    state = const AuthState.unauthenticated();
    debugPrint('AuthController.logout → $state');
  }

  String _deriveUserId(String email) {
    if (email.isEmpty) return 'local-user';
    return email.split('@').first;
  }

  String _deriveDisplayName(String email) {
    if (email.isEmpty) return 'User';
    final base = email.split('@').first;
    if (base.isEmpty) return 'User';
    return base[0].toUpperCase() + base.substring(1);
  }
}

/// Riverpod provider for AuthState
final authStateProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
