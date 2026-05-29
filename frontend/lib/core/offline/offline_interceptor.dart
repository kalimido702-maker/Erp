import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../network/connectivity_service.dart';
import 'local_database.dart';
import 'sync_manager.dart';
import 'sync_operation.dart';
import 'url_parser.dart';

/// A single Dio interceptor that provides zero-config offline support.
///
/// The programmer writes normal Dio calls. This interceptor:
///
///   GET (online)  → passes through → caches response + normalizes entities
///   GET (offline) → serves from response_cache → transparent to caller
///   GET (error)   → falls back to response_cache if available
///
///   POST/PUT/PATCH/DELETE (online)  → passes through → invalidates related caches
///   POST/PUT/PATCH/DELETE (offline) → saves locally + queues mutation → returns synthetic success
///   POST/PUT/PATCH/DELETE (error)   → non-4xx: queues for retry
///
/// No model definitions required. Everything is inferred from the URL.
class OfflineInterceptor extends Interceptor {
  final LocalDatabase _db;
  final SyncManager _syncManager;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();
  final _log = Logger();

  static const _mutating = {'POST', 'PUT', 'PATCH', 'DELETE'};

  OfflineInterceptor(this._db, this._syncManager, this._connectivity);

  // ──────────────────────────────────────────────
  // REQUEST — intercept before sending
  // ──────────────────────────────────────────────

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final method = options.method.toUpperCase();

    if (_connectivity.isOnline) {
      handler.next(options); // online → let it go
      return;
    }

    if (method == 'GET') {
      // Offline GET → try cache
      final key = _cacheKey(options);
      final cached = await _db.getCachedResponse(key);

      if (cached != null) {
        _log.i('[Offline↩] ${options.path}');
        handler.resolve(_cachedResponse(cached, options));
        return;
      }
      // No cache → let it fail (onError will handle it)
      handler.next(options);
      return;
    }

    if (_mutating.contains(method)) {
      // Offline mutation → queue + synthetic response
      final parsed = UrlParser.parse(options.path);
      final payload = _extractPayload(options);
      final localId = _uuid.v4();

      // Persist locally so it's immediately readable
      final localData = {...payload, 'id': parsed.id ?? localId, '_offline': true, '_local_id': localId};
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

      _log.i('[Offline⬆] Queued ${method} ${options.path} [${parsed.entity}]');

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
  // RESPONSE — intercept after server replies
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

      // Cache raw response
      await _db.cacheResponse(key, parsed.entity, response.data, ttl);

      // Normalize individual entities out of the response
      await _normalizeFromResponse(parsed, response.data);

      _log.d('[Cache✓] ${parsed.entity} ttl=${ttl.inMinutes}m key=$key');
    }

    if (_mutating.contains(method) && status < 400) {
      // Successful mutation → invalidate stale caches
      await _invalidate(method, path, response.data);
    }

    handler.next(response);
  }

  // ──────────────────────────────────────────────
  // ERROR — network failures, server errors
  // ──────────────────────────────────────────────

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    final path = err.requestOptions.path;
    final isNetworkErr = err.type != DioExceptionType.badResponse;
    final statusCode = err.response?.statusCode ?? 0;

    if (method == 'GET' && isNetworkErr) {
      // Network failure on GET → serve from cache if available
      final key = _cacheKey(err.requestOptions);
      final cached = await _db.getCachedResponse(key);
      if (cached != null) {
        _log.w('[Cache↩] Network error, serving stale cache: $path');
        handler.resolve(_cachedResponse(cached, err.requestOptions));
        return;
      }
    }

    if (_mutating.contains(method) && isNetworkErr) {
      // Network failure on mutation → queue for retry
      final parsed = UrlParser.parse(path);
      final payload = _extractPayload(err.requestOptions);
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
  // PRIVATE HELPERS
  // ──────────────────────────────────────────────

  /// Canonical cache key: path + sorted query params.
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
    if (d is String) {
      try {
        return jsonDecode(d) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  SyncOperationType _toOperation(String method) => switch (method) {
        'POST' => SyncOperationType.create,
        'DELETE' => SyncOperationType.delete,
        _ => SyncOperationType.update,
      };

  /// Extract individual items from the API response and store them normalized.
  /// Works automatically for any shape:
  ///   { data: [ {id:1, ...}, {id:2, ...} ] }   → list
  ///   { data: {id:1, ...} }                     → single item
  ///   { data: { items: [...] } }                → nested list (best-effort)
  Future<void> _normalizeFromResponse(ParsedUrl parsed, dynamic responseBody) async {
    if (responseBody is! Map) return;
    final data = responseBody['data'];

    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          await _saveNormalizedItem(parsed.entity, item);
        }
      }
    } else if (data is Map<String, dynamic>) {
      // Single item — might have nested 'items', 'lines', 'details' arrays
      await _saveNormalizedItem(parsed.entity, data);

      // Recursively normalize nested lists (e.g. order_items inside an order)
      for (final entry in data.entries) {
        if (entry.value is List) {
          final subEntity = '${parsed.entity}_${entry.key}';
          for (final sub in entry.value as List) {
            if (sub is Map<String, dynamic>) {
              await _saveNormalizedItem(subEntity, sub);
            }
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

  /// Invalidate URL caches after a successful mutation.
  Future<void> _invalidate(String method, String path, dynamic responseBody) async {
    final keys = UrlParser.invalidationKeys(method, path);

    // Also invalidate the URL returned in 'data.links' if API provides it
    if (responseBody is Map) {
      final links = responseBody['data']?['links'];
      if (links is Map) {
        final self = links['self']?.toString();
        if (self != null) keys.add(self);
      }
    }

    for (final key in keys) {
      await _db.invalidateCacheByPrefix(key);
    }
    _log.d('[Cache✗] Invalidated: $keys');
  }
}
