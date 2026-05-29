import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../errors/error_handler.dart';
import '../errors/failures.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import 'local_database.dart';
import 'sync_manager.dart';
import 'sync_operation.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json);
typedef ToJson<T> = Map<String, dynamic> Function(T entity);

/// Base repository with offline-first behavior.
///
/// Usage per feature:
/// ```dart
/// class ProductRepository extends OfflineFirstRepository<Product> {
///   ProductRepository(super.db, super.syncManager, super.apiClient, super.connectivity)
///       : super(entity: 'product');
///
///   @override
///   Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);
///
///   @override
///   Map<String, dynamic> toJson(Product entity) => entity.toJson();
/// }
/// ```
abstract class OfflineFirstRepository<T> {
  final String entity;
  final LocalDatabase _db;
  final SyncManager _syncManager;
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final _log = Logger();
  final _uuid = const Uuid();

  OfflineFirstRepository({
    required this.entity,
    required LocalDatabase db,
    required SyncManager syncManager,
    required ApiClient apiClient,
    required ConnectivityService connectivity,
  })  : _db = db,
        _syncManager = syncManager,
        _apiClient = apiClient,
        _connectivity = connectivity;

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T entity);

  // ──────────────────────────────────────────────
  // READ — Network first, fallback to cache
  // ──────────────────────────────────────────────

  Future<Either<Failure, List<T>>> fetchList({
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Duration cacheTtl = const Duration(hours: 6),
    String? cacheKey,
  }) async {
    final key = cacheKey ?? 'list:${queryParams.toString()}';

    if (_connectivity.isOnline) {
      try {
        final response = await _apiClient.dio.get(endpoint, queryParameters: queryParams);
        final rawList = response.data['data'] as List<dynamic>;
        final items = rawList.map((e) => fromJson(e as Map<String, dynamic>)).toList();

        // Update cache
        await _db.cacheEntity(entity, key, rawList, ttl: cacheTtl);

        // Also persist each item individually for offline editing
        for (final raw in rawList) {
          final map = raw as Map<String, dynamic>;
          final id = map['id']?.toString() ?? _uuid.v4();
          await _db.saveLocalEntity(
            localId: id,
            serverId: id,
            entity: entity,
            data: map,
            isDirty: false,
          );
        }

        return Right(items);
      } on DioException catch (e) {
        _log.w('[$entity] Fetch failed, falling back to cache: $e');
        return _getCachedList(key);
      }
    } else {
      _log.i('[$entity] Offline — serving from cache');
      return _getCachedList(key);
    }
  }

  Future<Either<Failure, List<T>>> _getCachedList(String key) async {
    final cached = await _db.getCached<List<dynamic>>(entity, key, (json) => json as List<dynamic>);
    if (cached != null) {
      final items = cached.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      return Right(items);
    }
    // Fall back to local_entities
    final dirty = await _db.getDirtyEntities(entity);
    if (dirty.isNotEmpty) {
      return Right(dirty.map((e) => fromJson(e)).toList());
    }
    return const Left(NetworkFailure());
  }

  Future<Either<Failure, T>> fetchOne({
    required String endpoint,
    required String id,
    Duration cacheTtl = const Duration(hours: 1),
  }) async {
    if (_connectivity.isOnline) {
      try {
        final response = await _apiClient.dio.get(endpoint);
        final raw = response.data['data'] as Map<String, dynamic>;
        final item = fromJson(raw);

        await _db.saveLocalEntity(
          localId: id,
          serverId: id,
          entity: entity,
          data: raw,
          isDirty: false,
        );
        await _db.cacheEntity(entity, id, raw, ttl: cacheTtl);

        return Right(item);
      } on DioException catch (e) {
        return _getCachedOne(id, e);
      }
    } else {
      return _getCachedOne(id, null);
    }
  }

  Future<Either<Failure, T>> _getCachedOne(String id, DioException? e) async {
    final local = await _db.getLocalEntity(entity, id);
    if (local != null) return Right(fromJson(local));
    final cached = await _db.getCached<Map<String, dynamic>>(entity, id, (j) => j as Map<String, dynamic>);
    if (cached != null) return Right(fromJson(cached));
    return Left(e != null ? handleDioError(e) : const NetworkFailure());
  }

  // ──────────────────────────────────────────────
  // CREATE — optimistic local, queue for sync
  // ──────────────────────────────────────────────

  Future<Either<Failure, T>> create({
    required String endpoint,
    required T data,
    int priority = 0,
  }) async {
    final localId = _uuid.v4();
    final payload = toJson(data);
    payload['_local_id'] = localId;

    // Save locally immediately (optimistic)
    await _db.saveLocalEntity(
      localId: localId,
      entity: entity,
      data: payload,
      isDirty: true,
    );

    // Enqueue for sync
    await _syncManager.enqueue(SyncOperation(
      id: _uuid.v4(),
      entity: entity,
      entityId: localId,
      operation: SyncOperationType.create,
      method: 'POST',
      endpoint: endpoint,
      payload: payload,
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    _log.d('[$entity] Created locally (offline-first): $localId');
    return Right(fromJson({...payload, 'id': localId, '_is_dirty': true}));
  }

  // ──────────────────────────────────────────────
  // UPDATE — optimistic local, queue for sync
  // ──────────────────────────────────────────────

  Future<Either<Failure, T>> update({
    required String endpoint,
    required String id,
    required T data,
    int priority = 0,
  }) async {
    final payload = toJson(data);

    // Merge with existing local data
    final existing = await _db.getLocalEntity(entity, id);
    final merged = {...(existing ?? {}), ...payload};
    merged.remove('_local_id');
    merged.remove('_is_dirty');

    await _db.saveLocalEntity(
      localId: id,
      serverId: id,
      entity: entity,
      data: merged,
      isDirty: true,
    );

    await _syncManager.enqueue(SyncOperation(
      id: _uuid.v4(),
      entity: entity,
      entityId: id,
      operation: SyncOperationType.update,
      method: 'PUT',
      endpoint: endpoint,
      payload: payload,
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    return Right(fromJson({...merged, '_is_dirty': true}));
  }

  // ──────────────────────────────────────────────
  // DELETE — remove locally, queue for sync
  // ──────────────────────────────────────────────

  Future<Either<Failure, void>> delete({
    required String endpoint,
    required String id,
    int priority = 0,
  }) async {
    // Remove from local cache immediately
    await _db.deleteLocalEntity(entity, id);

    await _syncManager.enqueue(SyncOperation(
      id: _uuid.v4(),
      entity: entity,
      entityId: id,
      operation: SyncOperationType.delete,
      method: 'DELETE',
      endpoint: endpoint,
      payload: {},
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    return const Right(null);
  }
}
