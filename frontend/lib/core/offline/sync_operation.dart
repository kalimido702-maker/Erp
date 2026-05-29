import 'dart:convert';

enum SyncOperationType { create, update, delete }

enum SyncStatus { pending, syncing, failed, completed }

class SyncOperation {
  final String id;
  final String entity;

  /// Local ID (UUID) when creating offline; server ID when updating/deleting
  final String entityId;
  final SyncOperationType operation;
  final String method; // POST, PUT, PATCH, DELETE
  final String endpoint;
  final Map<String, dynamic> payload;

  /// Higher priority = processed first
  final int priority;
  int retryCount;
  SyncStatus status;
  String? errorMessage;
  final DateTime createdAt;
  DateTime updatedAt;

  SyncOperation({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.method,
    required this.endpoint,
    required this.payload,
    this.priority = 0,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get nextRetryDelay {
    const base = [5, 15, 45, 135, 405]; // seconds
    final idx = retryCount.clamp(0, base.length - 1);
    return Duration(seconds: base[idx]);
  }

  bool get canRetry => retryCount < 5;

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity': entity,
        'entity_id': entityId,
        'operation': operation.name,
        'method': method,
        'endpoint': endpoint,
        'payload': jsonEncode(payload),
        'priority': priority,
        'retry_count': retryCount,
        'status': status.name,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SyncOperation.fromMap(Map<String, dynamic> map) => SyncOperation(
        id: map['id'] as String,
        entity: map['entity'] as String,
        entityId: map['entity_id'] as String,
        operation: SyncOperationType.values.byName(map['operation'] as String),
        method: map['method'] as String,
        endpoint: map['endpoint'] as String,
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        priority: map['priority'] as int,
        retryCount: map['retry_count'] as int,
        status: SyncStatus.values.byName(map['status'] as String),
        errorMessage: map['error_message'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  SyncOperation copyWith({
    int? retryCount,
    SyncStatus? status,
    String? errorMessage,
  }) =>
      SyncOperation(
        id: id,
        entity: entity,
        entityId: entityId,
        operation: operation,
        method: method,
        endpoint: endpoint,
        payload: payload,
        priority: priority,
        retryCount: retryCount ?? this.retryCount,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
