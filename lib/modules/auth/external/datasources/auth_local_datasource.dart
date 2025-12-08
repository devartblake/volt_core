import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/hive/hive_service.dart';
import '../../domain/user_role.dart';

class AuthLocalUser {
  final String? email;
  final UserRole? role;

  const AuthLocalUser({this.email, this.role});

  @override
  String toString() => 'AuthLocalUser(email: $email, role: $role)';
}

class AuthLocalDataSource {
  static const _boxName = 'auth_prefs';
  static const _keyEmail = 'email';
  static const _keyRole = 'role';

  Future<void> saveUser({
    required String email,
    required UserRole role,
  }) async {
    final box = await HiveService.openBox<dynamic>(_boxName);
    await box.put(_keyEmail, email);
    await box.put(_keyRole, role.name);

    if (kDebugMode) {
      debugPrint('[AuthLocalDataSource] saved email=$email, role=$role');
    }
  }

  Future<AuthLocalUser> loadUser() async {
    final box = await HiveService.openBox<dynamic>(_boxName);
    final email = box.get(_keyEmail) as String?;
    final roleName = box.get(_keyRole) as String?;
    final role = _parseRole(roleName);

    final result = AuthLocalUser(email: email, role: role);

    if (kDebugMode) {
      debugPrint('[AuthLocalDataSource] loadUser → $result');
    }

    return result;
  }

  Future<void> clear() async {
    final box = await HiveService.openBox<dynamic>(_boxName);
    await box.clear();
  }

  UserRole? _parseRole(String? name) {
    if (name == null) return null;
    try {
      return UserRole.values.firstWhere(
            (r) => r.name == name,
        orElse: () => UserRole.tech,
      );
    } catch (_) {
      return null;
    }
  }
}
