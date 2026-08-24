import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/user_role.dart';
import '../../state/auth_state.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import 'auth_providers.dart';
import '../../../../core/services/tenants/tenants_service.dart';
import '../../../../core/services/tenants/tenants_remote_datasource.dart';

class AuthController extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final Ref _ref;

  AuthController(
    this._ref,
    this._loginUseCase,
    this._logoutUseCase,
  ) : super(const AuthState.unauthenticated());

  Future<void> login({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    try {
      final params = LoginParams(
        email: email,
        password: password,
        preferredRole: role,
      );

      final newState = await _loginUseCase(params);
      state = newState;

      debugPrint('AuthController.login → $state');

      final userId = newState.userId;
      if (userId != null && userId.isNotEmpty) {
        try {
          final tenantsService = await _ref.read(tenantsServiceProvider.future);
          final remote = TenantsRemoteDatasource();
          final tenants = await remote.fetchTenantsForUser(userId);

          if (tenants.isNotEmpty) {
            await tenantsService.setTenants(tenants);
          }
        } catch (e, st) {
          debugPrint('AuthController.login → tenant sync failed: $e\n$st');
        }
      }
    } catch (e, st) {
      debugPrint('AuthController.login ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> restoreSession(AuthState? restored) async {
    if (restored == null) return;
    state = restored;
    debugPrint('AuthController.restoreSession → $state');
  }

  void switchRole(UserRole role) {
    if (!state.isAuthenticated) return;
    if (!state.canActAs(role)) {
      debugPrint('AuthController.switchRole → refused $role '
          '(granted: ${state.grantedRoles})');
      return;
    }
    state = state.copyWith(currentRole: role);
    debugPrint('AuthController.switchRole → $state');
  }

  Future<void> changePassword(String newPassword) async {
    if (!state.isAuthenticated) {
      throw StateError('Cannot change password while signed out.');
    }
    await _ref.read(authRepositoryProvider).changePassword(newPassword);
  }

  Future<void> logout() async {
    try {
      await _logoutUseCase();
    } catch (e, st) {
      debugPrint('AuthController.logout ERROR (remote/local): $e\n$st');
    } finally {
      state = const AuthState.unauthenticated();
      debugPrint('AuthController.logout → $state');
    }
  }
}

final authStateProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final logoutUseCase = ref.watch(logoutUseCaseProvider);

  final controller = AuthController(
    ref,
    loginUseCase,
    logoutUseCase,
  );

  ref.read(authRepositoryProvider).restoreSession().then(
    controller.restoreSession,
    onError: (Object e) {
      debugPrint('authStateProvider.restoreSession failed: $e');
    },
  );

  return controller;
});
