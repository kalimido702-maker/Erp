import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/app_constants.dart';
import '../offline/local_database.dart';
import '../offline/offline_interceptor.dart';
import '../offline/sync_manager.dart';
import 'connectivity_service.dart';

// Interceptor order matters:
//   Request  → [Auth] → [Offline] → network
//   Response ← [Logger] ← [Offline] ← network
//   Error    ← [Logger] ← [Offline] ← network
//
// OfflineInterceptor sits after Auth so the token is always set
// before it tries to replay cached responses.

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
    syncManager: ref.read(syncManagerProvider),
    connectivity: ref.read(connectivityServiceProvider),
  );
});

class ApiClient {
  late final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient({
    required FlutterSecureStorage storage,
    required SyncManager syncManager,
    required ConnectivityService connectivity,
  }) : _storage = storage {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      OfflineInterceptor(LocalDatabase.instance, syncManager, connectivity),
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        compact: true,
      ),
    ]);
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired — SyncManager will pause; router redirect handles UI
    }
    handler.next(err);
  }
}
