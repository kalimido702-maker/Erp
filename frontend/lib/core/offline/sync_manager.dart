import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import '../network/api_client.dart';
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
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final _log = Logger();

  final _stateSubject = BehaviorSubject<SyncManagerState>.seeded(SyncManagerState.idle);
  final _pendingCountSubject = BehaviorSubject<int>.seeded(0);

  StreamSubscription? _connectivitySub;
  Timer? _retryTimer;
  bool _isSyncing = false;

  SyncManager(this._db, this._apiClient, this._connectivity) {
    _init();
  }

  Stream<SyncManagerState> get onStateChange => _stateSubject.stream;
  Stream<int> get onPendingCountChange => _pendingCountSubject.stream;
  SyncManagerState get state => _stateSubject.value;
  int get pendingCount => _pendingCountSubject.value;

  void _init() {
    // Sync whenever we come back online
    _connectivitySub = _connectivity.onStateChange.listen((state) {
      if (state == NetworkState.online) {
        _log.i('[SyncManager] Back online — starting sync');
        syncNow();
      }
    });

    // Refresh pending count every time something changes
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final count = await _db.getPendingCount();
    _pendingCountSubject.add(count);
  }

  /// Enqueue a new operation, then attempt immediate sync if online
  Future<void> enqueue(SyncOperation op) async {
    await _db.enqueueSyncOperation(op);
    await _refreshPendingCount();

    if (_connectivity.isOnline) {
      syncNow();
    }
  }

  /// Process all pending operations in priority order
  Future<SyncResult> syncNow() async {
    if (_isSyncing) return const SyncResult(succeeded: 0, failed: 0, errors: []);
    if (!_connectivity.isOnline) return const SyncResult(succeeded: 0, failed: 0, errors: []);

    _isSyncing = true;
    _stateSubject.add(SyncManagerState.syncing);

    int succeeded = 0;
    final errors = <String>[];

    try {
      // Deduplicate before processing
      await _db.deduplicateQueue();

      final operations = await _db.getPendingOperations();
      _log.i('[SyncManager] Processing ${operations.length} pending operations');

      for (final op in operations) {
        if (!_connectivity.isOnline) {
          _log.w('[SyncManager] Lost connection mid-sync, stopping');
          break;
        }

        final success = await _processOperation(op);
        if (success) {
          succeeded++;
        } else {
          errors.add('${op.entity}:${op.entityId} — ${op.errorMessage}');
          // Schedule retry with exponential backoff
          if (op.canRetry) {
            _scheduleRetry(op.nextRetryDelay);
          }
        }
      }
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();

      final failedCount = await _db.getFailedCount();
      _stateSubject.add(failedCount > 0 ? SyncManagerState.error : SyncManagerState.idle);
    }

    _log.i('[SyncManager] Sync complete: $succeeded succeeded, ${errors.length} failed');
    return SyncResult(succeeded: succeeded, failed: errors.length, errors: errors);
  }

  Future<bool> _processOperation(SyncOperation op) async {
    // Mark as syncing
    final syncing = op.copyWith(status: SyncStatus.syncing);
    await _db.updateSyncOperation(syncing);

    try {
      late Response<dynamic> response;

      switch (op.method) {
        case 'POST':
          response = await _apiClient.dio.post(op.endpoint, data: op.payload);
        case 'PUT':
          response = await _apiClient.dio.put(op.endpoint, data: op.payload);
        case 'PATCH':
          response = await _apiClient.dio.patch(op.endpoint, data: op.payload);
        case 'DELETE':
          response = await _apiClient.dio.delete(op.endpoint);
        default:
          throw Exception('Unknown method: ${op.method}');
      }

      // Success — get server-assigned ID if this was a create
      if (op.operation == SyncOperationType.create) {
        final serverId = response.data?['data']?['id']?.toString();
        if (serverId != null) {
          await _db.markEntitySynced(op.entityId, serverId);
        }
      } else if (op.operation == SyncOperationType.delete) {
        await _db.deleteLocalEntity(op.entity, op.entityId);
      } else {
        // Update: mark as synced
        await _db.markEntitySynced(op.entityId, op.entityId);
      }

      // Remove from queue
      await _db.deleteSyncOperation(op.id);
      _log.d('[SyncManager] ✓ ${op.operation.name} ${op.entity}/${op.entityId}');
      return true;
    } on DioException catch (e) {
      final isClientError = (e.response?.statusCode ?? 0) >= 400 && (e.response?.statusCode ?? 0) < 500;

      final updated = op.copyWith(
        retryCount: op.retryCount + 1,
        status: isClientError ? SyncStatus.failed : SyncStatus.pending,
        errorMessage: _extractErrorMessage(e),
      );
      await _db.updateSyncOperation(updated);

      _log.w('[SyncManager] ✗ ${op.operation.name} ${op.entity}/${op.entityId}: ${updated.errorMessage}');

      // 4xx = validation/auth error → mark permanently failed, no retry
      return false;
    } catch (e) {
      final updated = op.copyWith(
        retryCount: op.retryCount + 1,
        status: SyncStatus.pending,
        errorMessage: e.toString(),
      );
      await _db.updateSyncOperation(updated);
      return false;
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
      return (e.response?.data as Map)['message']?.toString() ?? e.message ?? 'Unknown error';
    }
    return e.message ?? e.type.name;
  }

  Future<int> clearFailedOperations() async {
    final db = _db;
    final database = await db.db;
    final count = await database.delete('sync_queue', where: "status = 'failed'");
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

// ──────────────────────────────────────────────
// Riverpod Provider
// ──────────────────────────────────────────────

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(
    LocalDatabase.instance,
    ref.read(apiClientProvider),
    ref.read(connectivityServiceProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final syncStateProvider = StreamProvider<SyncManagerState>((ref) {
  return ref.watch(syncManagerProvider).onStateChange;
});

final pendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncManagerProvider).onPendingCountChange;
});
