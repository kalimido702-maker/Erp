import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../errors/error_handler.dart';
import '../errors/failures.dart';
import '../network/api_client.dart';

/// Thin typed wrapper around Dio.
///
/// Offline behavior (caching, queuing, sync) is handled entirely by
/// [OfflineInterceptor] — no offline code needed here.
///
/// Subclasses only need to define:
///   - [fromJson] to deserialize API data
///   - Typed methods that call [get], [post], [put], [patch], [delete]
abstract class OfflineFirstRepository<T> {
  final ApiClient apiClient;

  const OfflineFirstRepository(this.apiClient);

  T fromJson(Map<String, dynamic> json);

  // ──────────────────────────────────────────────
  // READ
  // ──────────────────────────────────────────────

  Future<Either<Failure, List<T>>> getList(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final res = await apiClient.dio.get(endpoint, queryParameters: params);
      final data = res.data['data'];
      if (data is List) {
        return Right(data.map((e) => fromJson(e as Map<String, dynamic>)).toList());
      }
      return const Right([]);
    } on DioException catch (e) {
      return Left(handleDioError(e));
    }
  }

  Future<Either<Failure, T>> getOne(String endpoint) async {
    try {
      final res = await apiClient.dio.get(endpoint);
      return Right(fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(handleDioError(e));
    }
  }

  // ──────────────────────────────────────────────
  // WRITE  (interceptor handles offline queuing)
  // ──────────────────────────────────────────────

  Future<Either<Failure, T>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final res = await apiClient.dio.post(endpoint, data: body);
      return Right(fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(handleDioError(e));
    }
  }

  Future<Either<Failure, T>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final res = await apiClient.dio.put(endpoint, data: body);
      return Right(fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(handleDioError(e));
    }
  }

  Future<Either<Failure, void>> destroy(String endpoint) async {
    try {
      await apiClient.dio.delete(endpoint);
      return const Right(null);
    } on DioException catch (e) {
      return Left(handleDioError(e));
    }
  }
}
