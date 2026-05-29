import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'sync_operation.dart';

class LocalDatabase {
  static LocalDatabase? _instance;
  static Database? _db;

  LocalDatabase._();

  static LocalDatabase get instance => _instance ??= LocalDatabase._();

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'erp_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id          TEXT PRIMARY KEY,
        entity      TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        method      TEXT NOT NULL,
        endpoint    TEXT NOT NULL,
        payload     TEXT NOT NULL,
        priority    INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        status      TEXT DEFAULT 'pending',
        error_message TEXT,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    // Generic entity cache — stores paginated list responses
    await db.execute('''
      CREATE TABLE entity_cache (
        cache_key   TEXT PRIMARY KEY,
        entity      TEXT NOT NULL,
        data        TEXT NOT NULL,
        cached_at   TEXT NOT NULL,
        expires_at  TEXT
      )
    ''');

    // Stores individual entities for offline editing
    await db.execute('''
      CREATE TABLE local_entities (
        local_id    TEXT PRIMARY KEY,
        server_id   TEXT,
        entity      TEXT NOT NULL,
        data        TEXT NOT NULL,
        is_dirty    INTEGER DEFAULT 0,
        synced_at   TEXT,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status, priority DESC, created_at ASC)');
    await db.execute('CREATE INDEX idx_local_entities_entity ON local_entities(entity, server_id)');
    await db.execute('CREATE INDEX idx_entity_cache_entity ON entity_cache(entity)');
  }

  // ──────────────────────────────────────────────
  // SYNC QUEUE
  // ──────────────────────────────────────────────

  Future<void> enqueueSyncOperation(SyncOperation op) async {
    final database = await db;
    await database.insert(
      'sync_queue',
      op.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncOperation>> getPendingOperations() async {
    final database = await db;
    final rows = await database.query(
      'sync_queue',
      where: "status IN ('pending', 'failed') AND retry_count < 5",
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map(SyncOperation.fromMap).toList();
  }

  Future<void> updateSyncOperation(SyncOperation op) async {
    final database = await db;
    await database.update(
      'sync_queue',
      op.toMap(),
      where: 'id = ?',
      whereArgs: [op.id],
    );
  }

  Future<void> deleteSyncOperation(String id) async {
    final database = await db;
    await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final database = await db;
    final result = await database.rawQuery(
      "SELECT COUNT(*) as cnt FROM sync_queue WHERE status IN ('pending','failed') AND retry_count < 5",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getFailedCount() async {
    final database = await db;
    final result = await database.rawQuery(
      "SELECT COUNT(*) as cnt FROM sync_queue WHERE status = 'failed'",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Deduplication: merge multiple updates for same entity+id into one
  Future<void> deduplicateQueue() async {
    final database = await db;
    // For each entity+entity_id with multiple 'update' ops, keep only the latest
    await database.rawDelete('''
      DELETE FROM sync_queue
      WHERE operation = 'update'
        AND status = 'pending'
        AND id NOT IN (
          SELECT id FROM sync_queue sq2
          WHERE sq2.operation = 'update'
            AND sq2.status = 'pending'
            AND sq2.entity = sync_queue.entity
            AND sq2.entity_id = sync_queue.entity_id
          ORDER BY sq2.created_at DESC
          LIMIT 1
        )
    ''');

    // If create + delete exist for same entity_id → cancel both
    final toCancel = await database.rawQuery('''
      SELECT entity_id, entity FROM sync_queue
      WHERE status = 'pending'
      GROUP BY entity, entity_id
      HAVING
        SUM(CASE WHEN operation = 'create' THEN 1 ELSE 0 END) > 0 AND
        SUM(CASE WHEN operation = 'delete' THEN 1 ELSE 0 END) > 0
    ''');
    for (final row in toCancel) {
      await database.delete(
        'sync_queue',
        where: "entity = ? AND entity_id = ? AND status = 'pending'",
        whereArgs: [row['entity'], row['entity_id']],
      );
    }
  }

  // ──────────────────────────────────────────────
  // ENTITY CACHE
  // ──────────────────────────────────────────────

  Future<void> cacheEntity(String entity, String key, dynamic data, {Duration ttl = const Duration(hours: 6)}) async {
    final database = await db;
    await database.insert(
      'entity_cache',
      {
        'cache_key': '$entity:$key',
        'entity': entity,
        'data': jsonEncode(data),
        'cached_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(ttl).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<T?> getCached<T>(String entity, String key, T Function(dynamic json) fromJson) async {
    final database = await db;
    final rows = await database.query(
      'entity_cache',
      where: 'cache_key = ? AND (expires_at IS NULL OR expires_at > ?)',
      whereArgs: ['$entity:$key', DateTime.now().toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return fromJson(jsonDecode(rows.first['data'] as String));
  }

  Future<void> clearExpiredCache() async {
    final database = await db;
    await database.delete(
      'entity_cache',
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  // ──────────────────────────────────────────────
  // LOCAL ENTITIES (offline-created / dirty)
  // ──────────────────────────────────────────────

  Future<void> saveLocalEntity({
    required String localId,
    String? serverId,
    required String entity,
    required Map<String, dynamic> data,
    bool isDirty = true,
  }) async {
    final database = await db;
    await database.insert(
      'local_entities',
      {
        'local_id': localId,
        'server_id': serverId,
        'entity': entity,
        'data': jsonEncode(data),
        'is_dirty': isDirty ? 1 : 0,
        'synced_at': isDirty ? null : DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLocalEntity(String entity, String id) async {
    final database = await db;
    final rows = await database.query(
      'local_entities',
      where: 'entity = ? AND (local_id = ? OR server_id = ?)',
      whereArgs: [entity, id, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      ...jsonDecode(rows.first['data'] as String) as Map<String, dynamic>,
      '_local_id': rows.first['local_id'],
      '_is_dirty': rows.first['is_dirty'] == 1,
    };
  }

  Future<List<Map<String, dynamic>>> getDirtyEntities(String entity) async {
    final database = await db;
    final rows = await database.query(
      'local_entities',
      where: 'entity = ? AND is_dirty = 1',
      whereArgs: [entity],
    );
    return rows.map((r) => {
          ...jsonDecode(r['data'] as String) as Map<String, dynamic>,
          '_local_id': r['local_id'],
          '_server_id': r['server_id'],
        }).toList();
  }

  Future<void> markEntitySynced(String localId, String serverId) async {
    final database = await db;
    await database.update(
      'local_entities',
      {
        'server_id': serverId,
        'is_dirty': 0,
        'synced_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLocalEntity(String entity, String id) async {
    final database = await db;
    await database.delete(
      'local_entities',
      where: 'entity = ? AND (local_id = ? OR server_id = ?)',
      whereArgs: [entity, id, id],
    );
  }
}
