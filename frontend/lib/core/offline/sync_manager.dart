import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../constants/app_constants.dart';
import '../network/connectivity_service.dart';
import 'local_database.dart';
import 'sync_operation.dart';

enum SyncManagerState { idle, syncing, error }

class SyncResult {
  final int succeeded;
  final int failed;
  final List<String> errors;
  const SyncResult({required this.succeeded, required this.failed, required this.errors});
  bool get hasErrors => failed > 0;
}

class SyncManager {
  final LocalDatabase _db;
  final ConnectivityService _connectivity;
  final FlutterSecureStorage _storage;
  final _log = Logger();

  // SyncManager owns its own Dio WITHOUT OfflineInterceptor.
  // This breaks the circular dependency and prevents the interceptor
  // from re-queuing sync operations that fail mid-flight.
  late final Dio _syncDio;

  final _stateSubject = BehaviorSubject<SyncManagerState>.seeded(SyncManagerState.idle);
  final _pendingCountSubject = BehaviorSubject<int>.seeded(0);

  StreamSubscription? _connectivitySub;
  Timer? _retryTimer;
  bool _isSyncing = false;

  SyncManager(this._db, this._connectivity, this._storage) {
    _syncDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    )..interceptors.add(_SyncAuthInterceptor(_storage));

    _connectivitySub = _connectivity.onStateChange.listen((state) {
      if (state == NetworkState.online) {
        _log.i('[SyncManager] Back online — starting sync');
        syncNow();
      }
    });

    _refreshPendingCount();
  }

  Stream<SyncManagerState> get onStateChange => _stateSubject.stream;
  Stream<int> get onPendingCountChange => _pendingCountSubject.stream;
  SyncManagerState get state => _stateSubject.value;
  int get pendingCount => _pendingCountSubject.value;

  Future<void> _refreshPendingCount() async {
    final count = await _db.getPendingCount();
    _pendingCountSubject.add(count);
  }

  Future<void> enqueue(SyncOperation op) async {
    await _db.enqueueSyncOperation(op);
    await _refreshPendingCount();
    if (_connectivity.isOnline) syncNow();
  }

  Future<SyncResult> syncNow() async {
    // No await between check and set → safe in Dart's cooperative model
    if (_isSyncing) return const SyncResult(succeeded: 0, failed: 0, errors: []);
    if (!_connectivity.isOnline) return const SyncResult(succeeded: 0, failed: 0, errors: []);

    _isSyncing = true;
    _stateSubject.add(SyncManagerState.syncing);

    int succeeded = 0;
    final errors = <String>[];

    try {
      // Fix #6: Verify token is valid before processing the queue.
      // If token expired, attempt refresh first. If refresh fails, abort.
      final tokenOk = await _ensureValidToken();
      if (!tokenOk) {
        _log.w('[SyncManager] Token invalid — aborting sync, user must re-login');
        _stateSubject.add(SyncManagerState.error);
        return const SyncResult(succeeded: 0, failed: 0, errors: ['انتهت صلاحية الجلسة']);
      }

      await _db.deduplicateQueue();
      final operations = await _db.getPendingOperations();
      _log.i('[SyncManager] Processing ${operations.length} pending operations');

      for (final op in operations) {
        if (!_connectivity.isOnline) {
          _log.w('[SyncManager] Lost connection mid-sync, pausing');
          break;
        }
        final success = await _processOperation(op);
        if (success) {
          succeeded++;
        } else {
          errors.add('${op.entity}:${op.entityId} — ${op.errorMessage}');
          if (op.canRetry) _scheduleRetry(op.nextRetryDelay);
        }
      }
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();
      final failedCount = await _db.getFailedCount();
      _stateSubject.add(failedCount > 0 ? SyncManagerState.error : SyncManagerState.idle);
    }

    _log.i('[SyncManager] Sync done: $succeeded ok, ${errors.length} failed');
    return SyncResult(succeeded: succeeded, failed: errors.length, errors: errors);
  }

  Future<bool> _processOperation(SyncOperation op) async {
    await _db.updateSyncOperation(op.copyWith(status: SyncStatus.syncing));

    try {
      late Response<dynamic> response;

      // Fix #7: Conflict detection — send the last known updated_at so
      // the server can return 409 if another user modified the record.
      final conflictHeaders = op.operation == SyncOperationType.update && op.payload['updated_at'] != null
          ? {'If-Unmodified-Since': op.payload['updated_at'].toString()}
          : <String, String>{};

      switch (op.method) {
        case 'POST':
          response = await _syncDio.post(op.endpoint, data: op.payload);
        case 'PUT':
          response = await _syncDio.put(op.endpoint, data: op.payload, options: Options(headers: conflictHeaders));
        case 'PATCH':
          response = await _syncDio.patch(op.endpoint, data: op.payload, options: Options(headers: conflictHeaders));
        case 'DELETE':
          response = await _syncDio.delete(op.endpoint);
        default:
          throw Exception('Unknown method: ${op.method}');
      }

      // Write back server state to normalized_entities
      if (op.operation == SyncOperationType.create) {
        final serverData = response.data?['data'] as Map<String, dynamic>?;
        final serverId = serverData?['id']?.toString();
        if (serverId != null && serverData != null) {
          await _db.markNormalizedSynced(op.entityId, serverId, op.entity);
          await _db.saveNormalized(entity: op.entity, serverId: serverId, localId: op.entityId, data: serverData);
        }
      } else if (op.operation == SyncOperationType.delete) {
        await _db.deleteNormalized(op.entity, op.entityId);
      } else {
        final serverData = response.data?['data'] as Map<String, dynamic>?;
        if (serverData != null) {
          await _db.saveNormalized(entity: op.entity, serverId: op.entityId, data: serverData);
        } else {
          await _db.markNormalizedSynced(op.entityId, op.entityId, op.entity);
        }
      }

      await _db.deleteSyncOperation(op.id);
      _log.d('[SyncManager] ✓ ${op.operation.name} ${op.entity}/${op.entityId}');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final isClientError = status >= 400 && status < 500;

      // Fix #7: Handle 409 Conflict — user must resolve manually
      if (status == 409) {
        _log.w('[SyncManager] ⚡ Conflict on ${op.entity}/${op.entityId}');
        final updated = op.copyWith(
          status: SyncStatus.failed,
          errorMessage: 'تعارض: تم تعديل البيانات من مستخدم آخر، يرجى المراجعة',
        );
        await _db.updateSyncOperation(updated);
        return false;
      }

      final updated = op.copyWith(
        retryCount: op.retryCount + 1,
        status: isClientError ? SyncStatus.failed : SyncStatus.pending,
        errorMessage: _extractErrorMessage(e),
      );
      await _db.updateSyncOperation(updated);
      _log.w('[SyncManager] ✗ ${op.operation.name} ${op.entity}/${op.entityId}: ${updated.errorMessage}');
      return false;
    } catch (e) {
      final updated = op.copyWith(retryCount: op.retryCount + 1, status: SyncStatus.pending, errorMessage: e.toString());
      await _db.updateSyncOperation(updated);
      return false;
    }
  }

  /// Verify token is still valid. Returns false if user must re-login.
  Future<bool> _ensureValidToken() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return false;

    try {
      // Light ping: call /auth/me to verify token
      await _syncDio.get('/auth/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Try refresh endpoint
        try {
          final res = await _syncDio.post('/auth/refresh');
          final newToken = res.data?['data']?['token'] as String?;
          if (newToken != null) {
            await _storage.write(key: AppConstants.tokenKey, value: newToken);
            return true;
          }
        } catch (_) {}
        // Refresh failed — token truly expired
        await _storage.delete(key: AppConstants.tokenKey);
        return false;
      }
      // Other errors (network) — assume token is OK, try anyway
      return true;
    }
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_connectivity.isOnline) syncNow();
    });
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data is Map) {
      return (e.response!.data as Map)['message']?.toString() ?? e.message ?? 'خطأ غير معروف';
    }
    return e.message ?? e.type.name;
  }

  /// Fix #9: Clear failed ops AND their orphaned dirty normalized_entities.
  Future<int> clearFailedOperations() async {
    final database = await _db.db;

    // Collect entity+entityId of failed ops before deleting
    final failed = await database.query(
      'sync_queue',
      where: "status = 'failed'",
      columns: ['entity', 'entity_id'],
    );

    final count = await database.delete('sync_queue', where: "status = 'failed'");

    // Also clean up orphaned dirty records with no corresponding queue entry
    for (final row in failed) {
      final stillQueued = await database.query(
        'sync_queue',
        where: 'entity=? AND entity_id=?',
        whereArgs: [row['entity'], row['entity_id']],
        limit: 1,
      );
      if (stillQueued.isEmpty) {
        await _db.deleteNormalized(row['entity'] as String, row['entity_id'] as String);
      }
    }

    await _refreshPendingCount();
    return count;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _stateSubject.close();
    _pendingCountSubject.close();
  }
}

/// Auth interceptor for the sync-only Dio (no offline queuing).
class _SyncAuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _SyncAuthInterceptor(this._storage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

// ──────────────────────────────────────────────
// Providers — no circular dependency:
//   syncManagerProvider → does NOT read apiClientProvider
//   apiClientProvider   → reads syncManagerProvider
// ──────────────────────────────────────────────

final syncManagerProvider = Provider<SyncManager>((ref) {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final manager = SyncManager(LocalDatabase.instance, ref.read(connectivityServiceProvider), storage);
  ref.onDispose(manager.dispose);
  return manager;
});

final syncStateProvider = StreamProvider<SyncManagerState>((ref) {
  return ref.watch(syncManagerProvider).onStateChange;
});

final pendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncManagerProvider).onPendingCountChange;
});
