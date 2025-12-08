import '../../domain/user_role.dart';
import '../../state/auth_state.dart';

abstract class AuthRepository {
  /// Login using email + password (Supabase).
  ///
  /// [preferredRole] can come from your role selector (tech/supervisor/etc).
  /// Implementations may still override this based on server-side role.
  Future<AuthState> loginWithEmailPassword({
    required String email,
    required String password,
    required UserRole preferredRole,
  });

  /// Try to restore the current authenticated user (Supabase + local cache).
  Future<AuthState?> restoreSession();

  /// Logout and clear any local cache.
  Future<void> logout();
}