import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/user_role.dart';
import '../../state/auth_state.dart';

/// Controller (StateNotifier) for AuthState.
///
/// In the future you can:
/// - inject an AuthRepository
/// - call Supabase or any backend here
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