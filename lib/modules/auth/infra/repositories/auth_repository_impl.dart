import 'package:flutter/foundation.dart';

import '../../domain/user_role.dart';
import '../../state/auth_state.dart';
import '../../external/datasources/auth_remote_datasource.dart';
import '../../external/datasources/auth_local_datasource.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  @override
  Future<AuthState> loginWithEmailPassword({
    required String email,
    required String password,
    required UserRole preferredRole,
  }) async {
    final remoteUser = await _remote.loginWithEmailPassword(
      email: email,
      password: password,
      preferredRole: preferredRole,
    );

    // Persist local info for auto-fill / restore.
    await _local.saveUser(email: remoteUser.email, role: remoteUser.role);

    final authState = AuthState(
      isAuthenticated: true,
      currentRole: remoteUser.role,
      userId: remoteUser.userId,
      email: remoteUser.email,
      displayName: remoteUser.displayName,
      grantedRoles: remoteUser.grantedRoles,
    );

    if (kDebugMode) {
      debugPrint('[AuthRepositoryImpl] loginWithEmailPassword → $authState');
    }

    return authState;
  }

  @override
  Future<AuthState?> restoreSession() async {
    final localUser = await _local.loadUser();

    // The locally stored role is only a *preference* for which of the user's
    // granted roles to resume as — the datasource validates it against the
    // server's grants, so a tampered local store cannot escalate.
    final remoteUser =
        await _remote.getCurrentUser(preferredRole: localUser.role);

    // If Supabase has no user, we are unauthenticated.
    if (remoteUser == null) {
      if (kDebugMode) {
        debugPrint('[AuthRepositoryImpl] restoreSession → no remote user');
      }
      return null;
    }

    final state = AuthState(
      isAuthenticated: true,
      currentRole: remoteUser.role,
      userId: remoteUser.userId,
      email: remoteUser.email,
      displayName: remoteUser.displayName,
      grantedRoles: remoteUser.grantedRoles,
    );

    if (kDebugMode) {
      debugPrint('[AuthRepositoryImpl] restoreSession → $state');
    }

    return state;
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
    await _local.clear();

    if (kDebugMode) {
      debugPrint('[AuthRepositoryImpl] logout → OK');
    }
  }
}
