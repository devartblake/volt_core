import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../external/datasources/auth_remote_datasource.dart';
import '../../external/datasources/auth_local_datasource.dart';
import '../../infra/repositories/auth_repository.dart';
import '../../infra/repositories/auth_repository_impl.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  final local = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(remote: remote, local: local);
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repo);
});