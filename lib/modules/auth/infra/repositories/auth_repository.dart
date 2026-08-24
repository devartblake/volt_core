import '../../domain/user_role.dart';
import '../../state/auth_state.dart';

abstract class AuthRepository {
  Future<AuthState> loginWithEmailPassword({
    required String email,
    required String password,
    required UserRole preferredRole,
  });

  Future<AuthState?> restoreSession();

  Future<void> changePassword(String newPassword);

  Future<void> logout();
}
