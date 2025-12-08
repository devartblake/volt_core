import '../user_role.dart';

/// Pure domain-level representation of the authenticated user state.
///
/// This lives in the domain layer (no Flutter / Riverpod imports).
/// Presentation (`AuthState` + Riverpod) can map to/from this entity.
class AuthStateEntity {
  final bool isAuthenticated;
  final UserRole? role;
  final String? userId;
  final String? email;
  final String? displayName;

  const AuthStateEntity({
    required this.isAuthenticated,
    this.role,
    this.userId,
    this.email,
    this.displayName,
  });

  const AuthStateEntity.unauthenticated()
      : isAuthenticated = false,
        role = null,
        userId = null,
        email = null,
        displayName = null;

  AuthStateEntity copyWith({
    bool? isAuthenticated,
    UserRole? role,
    String? userId,
    String? email,
    String? displayName,
  }) {
    return AuthStateEntity(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  String toString() {
    return 'AuthStateEntity('
        'isAuthenticated: $isAuthenticated, '
        'role: $role, '
        'userId: $userId, '
        'email: $email, '
        'displayName: $displayName'
        ')';
  }
}
