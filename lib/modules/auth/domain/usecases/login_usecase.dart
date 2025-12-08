import '../../domain/user_role.dart';
import '../../state/auth_state.dart';
import '../../infra/repositories/auth_repository.dart';

class LoginParams {
  final String email;
  final String password;
  final UserRole preferredRole;

  const LoginParams({
    required this.email,
    required this.password,
    required this.preferredRole,
  });
}

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<AuthState> call(LoginParams params) {
    return _repository.loginWithEmailPassword(
      email: params.email,
      password: params.password,
      preferredRole: params.preferredRole,
    );
  }
}