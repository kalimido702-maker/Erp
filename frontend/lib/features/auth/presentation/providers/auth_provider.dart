import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/user_entity.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<UserEntity?> build() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: AppConstants.tokenKey);
    if (token == null) return null;

    try {
      final ds = ref.read(authDatasourceProvider);
      final model = await ds.getMe();
      return model.toEntity();
    } catch (_) {
      await storage.delete(key: AppConstants.tokenKey);
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final storage = ref.read(secureStorageProvider);
    final ds = ref.read(authDatasourceProvider);

    state = await AsyncValue.guard(() async {
      final result = await ds.login(email, password);
      await storage.write(key: AppConstants.tokenKey, value: result.token);
      return result.user.toEntity();
    });
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    final ds = ref.read(authDatasourceProvider);

    try {
      await ds.logout();
    } catch (_) {}

    await storage.delete(key: AppConstants.tokenKey);
    state = const AsyncData(null);
  }
}

@riverpod
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

@riverpod
AuthRemoteDatasource authDatasource(Ref ref) => AuthRemoteDatasource(ref.read(apiClientProvider));
