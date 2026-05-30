import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../network/connectivity_service.dart';
import 'local_database.dart';
import 'payload_sanitizer.dart';
import 'sync_manager.dart';
import 'sync_operation.dart';
import 'url_parser.dart';

/// Zero-config offline-first Dio interceptor.
///
/// GET  online  → pass through → cache response + normalize entities
/// GET  offline → serve from response_cache (transparent to caller)
/// GET  error   → fall back to response_cache
///
/// Mutation online  → pass through → invalidate stale caches
/// Mutation offline → save locally + queue + return synthetic success
/// Mutation error   → queue for retry (non-4xx only)
class OfflineInterceptor extends Interceptor {
  final LocalDatabase _db;
  final SyncManager _syncManager;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();
  final _log = Logger();

  static const _mutating = {'POST', 'PUT', 'PATCH', 'DELETE'};

  OfflineInterceptor(this._db, this._syncManager, this._connectivity);

  // ──────────────────────────────────────────────
  // REQUEST
  // ──────────────────────────────────────────────

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final method = options.method.toUpperCase();

    if (_connectivity.isOnline) {
      handler.next(options);
      return;
    }

    if (method == 'GET') {
      final cached = await _db.getCachedResponse(_cacheKey(options));
      if (cached != null) {
        _log.i('[Offline↩] ${options.path}');
        handler.resolve(_cachedResponse(cached, options));
        return;
      }
      handler.next(options); // No cache → let it fail → onError handles it
      return;
    }

    if (_mutating.contains(method)) {
      final parsed = UrlParser.parse(options.path);

      // Fix #3: always sanitize payload before encoding/storing
      final payload = sanitizePayload(_extractPayload(options));
      final localId = _uuid.v4();
      final localData = {...payload, 'id': parsed.id ?? localId, '_offline': true, '_local_id': localId};

      // Persist locally so data is immediately readable offline
      await _db.saveLocalOnly(entity: parsed.entity, localId: localId, data: localData);

      await _syncManager.enqueue(SyncOperation(
        id: _uuid.v4(),
        entity: parsed.entity,
        entityId: parsed.id ?? localId,
        operation: _toOperation(method),
        method: method,
        endpoint: options.path,
        payload: {...payload, if (parsed.id == null) '_local_id': localId},
        priority: UrlParser.inferPriority(parsed.entity, method),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      _log.i('[Offline⬆] Queued $method ${options.path} [${parsed.entity}]');

      handler.resolve(Response(
        requestOptions: options,
        statusCode: method == 'POST' ? 201 : 200,
        data: {
          'success': true,
          'offline': true,
          'message': 'محفوظ محلياً، ستتم المزامنة عند استعادة الاتصال',
          'data': localData,
        },
      ));
    }
  }

  // ──────────────────────────────────────────────
  // RESPONSE
  // ──────────────────────────────────────────────

  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    final method = response.requestOptions.method.toUpperCase();
    final path = response.requestOptions.path;
    final status = response.statusCode ?? 0;

    if (method == 'GET' && status == 200) {
      final key = _cacheKey(response.requestOptions);
      final parsed = UrlParser.parse(path);
      final ttl = UrlParser.inferTtl(parsed.entity);

      await _db.cacheResponse(key, parsed.entity, response.data, ttl);
      await _normalizeFromResponse(parsed, response.data);

      _log.d('[Cache✓] ${parsed.entity} ttl=${ttl.inMinutes}m');
    }

    if (_mutating.contains(method) && status < 400) {
      await _invalidate(method, path, response.data);
    }

    handler.next(response);
  }

  // ──────────────────────────────────────────────
  // ERROR
  // ──────────────────────────────────────────────

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    final path = err.requestOptions.path;
    final isNetworkErr = err.type != DioExceptionType.badResponse;

    if (method == 'GET' && isNetworkErr) {
      final cached = await _db.getCachedResponse(_cacheKey(err.requestOptions));
      if (cached != null) {
        _log.w('[Cache↩] Network error, stale cache: $path');
        handler.resolve(_cachedResponse(cached, err.requestOptions));
        return;
      }
    }

    if (_mutating.contains(method) && isNetworkErr) {
      // Fix #3: sanitize before queuing retry
      final parsed = UrlParser.parse(path);
      final payload = sanitizePayload(_extractPayload(err.requestOptions));
      final localId = _uuid.v4();

      await _syncManager.enqueue(SyncOperation(
        id: _uuid.v4(),
        entity: parsed.entity,
        entityId: parsed.id ?? localId,
        operation: _toOperation(method),
        method: method,
        endpoint: path,
        payload: payload,
        priority: UrlParser.inferPriority(parsed.entity, method),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      _log.w('[Retry⬆] Queued failed $method $path for retry');
    }

    handler.next(err);
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────

  String _cacheKey(RequestOptions opts) {
    final params = (opts.queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '${opts.path}${params.isNotEmpty ? '?$params' : ''}';
  }

  Response _cachedResponse(dynamic data, RequestOptions opts) => Response(
        requestOptions: opts,
        statusCode: 200,
        data: data,
        headers: Headers.fromMap({'x-erp-source': ['cache']}),
      );

  Map<String, dynamic> _extractPayload(RequestOptions opts) {
    final d = opts.data;
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  SyncOperationType _toOperation(String method) => switch (method) {
        'POST' => SyncOperationType.create,
        'DELETE' => SyncOperationType.delete,
        _ => SyncOperationType.update,
      };

  Future<void> _normalizeFromResponse(ParsedUrl parsed, dynamic body) async {
    if (body is! Map) return;
    final data = body['data'];

    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) await _saveNormalizedItem(parsed.entity, item);
      }
    } else if (data is Map<String, dynamic>) {
      await _saveNormalizedItem(parsed.entity, data);

      // Normalize nested arrays (e.g. order.items → sales_orders_items)
      for (final entry in data.entries) {
        if (entry.value is List) {
          final subEntity = '${parsed.entity}_${entry.key}';
          for (final sub in entry.value as List) {
            if (sub is Map<String, dynamic>) await _saveNormalizedItem(subEntity, sub);
          }
        }
      }
    }
  }

  Future<void> _saveNormalizedItem(String entity, Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null) return;
    await _db.saveNormalized(entity: entity, serverId: id, data: item);
  }

  Future<void> _invalidate(String method, String path, dynamic body) async {
    final keys = UrlParser.invalidationKeys(method, path);

    if (body is Map) {
      final self = body['data']?['links']?['self']?.toString();
      if (self != null) keys.add(self);
    }

    for (final key in keys) {
      await _db.invalidateCacheByPrefix(key);
    }
    _log.d('[Cache✗] Invalidated: $keys');
  }
}
