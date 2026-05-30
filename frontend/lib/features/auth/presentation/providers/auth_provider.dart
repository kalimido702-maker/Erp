import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_model.dart';
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
      await _cacheUser(model);
      final entity = model.toEntity();
      await _startRealtime(entity, token);
      return entity;
    } on UnauthorizedFailure {
      // 401 → the token is genuinely invalid/expired: clear the session.
      await _clearSession();
      return null;
    } catch (_) {
      // Network/server error (e.g. offline launch). The token is still valid,
      // so DO NOT log the user out — restore the last known user from cache so
      // the app opens authenticated and offline-first. Only fall back to login
      // if we have never cached a user on this device.
      final cached = await _cachedUser();
      if (cached != null) {
        await _startRealtime(cached, token);
      }
      return cached;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final storage = ref.read(secureStorageProvider);
    final ds = ref.read(authDatasourceProvider);

    state = await AsyncValue.guard(() async {
      final result = await ds.login(email, password);
      await storage.write(key: AppConstants.tokenKey, value: result.token);
      await _cacheUser(result.user);
      final entity = result.user.toEntity();
      await _startRealtime(entity, result.token);
      return entity;
    });
  }

  Future<void> logout() async {
    final ds = ref.read(authDatasourceProvider);

    ref.read(realtimeServiceProvider).disconnect();

    try {
      await ds.logout();
    } catch (_) {}

    await _clearSession();
    state = const AsyncData(null);
  }

  // ── session persistence helpers ──────────────────────────────────────

  Future<void> _cacheUser(UserModel model) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: AppConstants.userKey, value: jsonEncode(model.toJson()));
  }

  Future<UserEntity?> _cachedUser() async {
    final storage = ref.read(secureStorageProvider);
    final raw = await storage.read(key: AppConstants.userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>).toEntity();
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: AppConstants.tokenKey);
    await storage.delete(key: AppConstants.userKey);
  }

  /// Open the realtime channel for the user's company so push notifications
  /// (low stock, order approvals, …) arrive while the app is open.
  Future<void> _startRealtime(UserEntity user, String token) async {
    final companyId = user.companyId;
    if (companyId == null) return;
    await ref.read(realtimeServiceProvider).connect(companyId, token);
  }
}

@riverpod
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

@riverpod
AuthRemoteDatasource authDatasource(Ref ref) => AuthRemoteDatasource(ref.read(apiClientProvider));
