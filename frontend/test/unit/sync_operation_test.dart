import 'package:erp_app/core/offline/sync_operation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for the offline sync queue item. No device/bindings needed.
void main() {
  SyncOperation make({
    int retryCount = 0,
    SyncStatus status = SyncStatus.pending,
    Map<String, dynamic>? payload,
  }) {
    final now = DateTime.parse('2026-05-30T10:00:00.000Z');
    return SyncOperation(
      id: 'op-1',
      entity: 'inventory_products',
      entityId: 'abc-123',
      operation: SyncOperationType.create,
      method: 'POST',
      endpoint: '/api/v1/inventory/products',
      payload: payload ?? {'name': 'Laptop', 'price': 4500},
      priority: 7,
      retryCount: retryCount,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('nextRetryDelay (exponential backoff)', () {
    test('follows the 5/15/45/135/405 second schedule', () {
      expect(make(retryCount: 0).nextRetryDelay, const Duration(seconds: 5));
      expect(make(retryCount: 1).nextRetryDelay, const Duration(seconds: 15));
      expect(make(retryCount: 2).nextRetryDelay, const Duration(seconds: 45));
      expect(make(retryCount: 3).nextRetryDelay, const Duration(seconds: 135));
      expect(make(retryCount: 4).nextRetryDelay, const Duration(seconds: 405));
    });

    test('clamps to the last bucket beyond the schedule', () {
      expect(make(retryCount: 9).nextRetryDelay, const Duration(seconds: 405));
    });
  });

  group('canRetry', () {
    test('is true below 5 attempts', () {
      expect(make(retryCount: 0).canRetry, isTrue);
      expect(make(retryCount: 4).canRetry, isTrue);
    });

    test('is false at or above 5 attempts (gives up)', () {
      expect(make(retryCount: 5).canRetry, isFalse);
      expect(make(retryCount: 6).canRetry, isFalse);
    });
  });

  group('serialization', () {
    test('toMap/fromMap round-trips all fields incl. JSON payload', () {
      final original = make(retryCount: 2, status: SyncStatus.failed);
      final restored = SyncOperation.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.entity, original.entity);
      expect(restored.entityId, original.entityId);
      expect(restored.operation, original.operation);
      expect(restored.method, original.method);
      expect(restored.endpoint, original.endpoint);
      expect(restored.payload, original.payload);
      expect(restored.priority, original.priority);
      expect(restored.retryCount, original.retryCount);
      expect(restored.status, original.status);
      expect(restored.createdAt, original.createdAt);
    });

    test('payload is stored as an encoded JSON string in the map', () {
      final map = make().toMap();
      expect(map['payload'], isA<String>());
      expect(map['payload'], contains('Laptop'));
    });
  });

  group('copyWith', () {
    test('bumps retryCount and status without touching other fields', () {
      final op = make();
      final next = op.copyWith(retryCount: 1, status: SyncStatus.syncing);

      expect(next.retryCount, 1);
      expect(next.status, SyncStatus.syncing);
      expect(next.id, op.id);
      expect(next.payload, op.payload);
      expect(next.createdAt, op.createdAt);
    });

    test('refreshes updatedAt', () {
      final op = make();
      final next = op.copyWith(status: SyncStatus.completed);
      expect(next.updatedAt.isAfter(op.updatedAt), isTrue);
    });
  });
}
