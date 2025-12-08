import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/user_role.dart';
import '../../state/auth_state.dart';

// Usecases
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

// Providers that build the repository + usecases
import 'auth_providers.dart';

// Tenants service + remote datasource
import '../../../../core/services/tenants/tenants_service.dart';
import '../../../../core/services/tenants/tenants_remote_datasource.dart';

/// Controller (StateNotifier) for AuthState.
///
/// Uses:
/// - LoginUseCase (Supabase + Hive under the hood)
/// - LogoutUseCase
/// - TenantsService + TenantsRemoteDatasource (for multi-tenant support)
class AuthController extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final Ref _ref;

  AuthController(
      this._ref,
      this._loginUseCase,
      this._logoutUseCase,
      ) : super(const AuthState.unauthenticated());

  /// Login using email + password + selected role.
  ///
  /// 1) Calls Supabase via [LoginUseCase].
  /// 2) Updates [AuthState] from backend result.
  /// 3) Fetches tenants for this user and stores them via [TenantsService].
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

      // --- 1) Normal auth via usecase
      final newState = await _loginUseCase(params);
      state = newState;

      debugPrint('AuthController.login → $state');

      // --- 2) Tenants sync after login
      final userId = newState.userId;
      if (userId != null && userId.isNotEmpty) {
        try {
          // This is the snippet you wanted wired into the auth flow:
          final tenantsService =
          await _ref.read(tenantsServiceProvider.future);
          final remote = TenantsRemoteDatasource();
          final tenants = await remote.fetchTenantsForUser(userId);

          if (tenants.isNotEmpty) {
            await tenantsService.setTenants(tenants);
          }
        } catch (e, st) {
          debugPrint(
            'AuthController.login → tenant sync failed: $e\n$st',
          );
          // We intentionally swallow this so login still succeeds
        }
      }
    } catch (e, st) {
      debugPrint('AuthController.login ERROR: $e\n$st');
      // Rethrow so the UI can show an error snackbar/dialog.
      rethrow;
    }
  }

  /// Optional: restore session if you later add a RestoreSessionUseCase.
  /// For now, you can keep this as a placeholder or ignore it.
  Future<void> restoreSession(AuthState? restored) async {
    if (restored == null) return;
    state = restored;
    debugPrint('AuthController.restoreSession → $state');
  }

  /// Switch role for the currently logged-in user.
  ///
  /// This is still local-only; if you want to persist role changes
  /// to Hive or Supabase, we can later add a dedicated usecase and repo.
  void switchRole(UserRole role) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(currentRole: role);
    debugPrint('AuthController.switchRole → $state');
  }

  /// Logout / clear auth.
  ///
  /// Calls [LogoutUseCase] (Supabase signOut + Hive clear),
  /// then resets local [AuthState].
  Future<void> logout() async {
    try {
      await _logoutUseCase();
    } catch (e, st) {
      debugPrint('AuthController.logout ERROR (remote/local): $e\n$st');
      // Even if remote logout fails, we still reset local state below.
    } finally {
      state = const AuthState.unauthenticated();
      debugPrint('AuthController.logout → $state');
    }
  }
}

/// Riverpod provider for AuthState.
///
/// Wires in:
/// - [LoginUseCase] via [loginUseCaseProvider]
/// - [LogoutUseCase] via [logoutUseCaseProvider]
/// - passes [ref] into AuthController so we can read TenantsService
final authStateProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final logoutUseCase = ref.watch(logoutUseCaseProvider);

  return AuthController(
    ref,
    loginUseCase,
    logoutUseCase,
  );
});
