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
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop old tables and recreate (dev phase — no migration needed)
      for (final t in ['sync_queue', 'entity_cache', 'local_entities', 'response_cache', 'normalized_entities']) {
        await db.execute('DROP TABLE IF EXISTS $t');
      }
      await _createSchema(db);
    }
  }

  Future<void> _createSchema(Database db) async {
    // Pending mutations waiting to be synced
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id            TEXT PRIMARY KEY,
        entity        TEXT NOT NULL,
        entity_id     TEXT NOT NULL,
        operation     TEXT NOT NULL,
        method        TEXT NOT NULL,
        endpoint      TEXT NOT NULL,
        payload       TEXT NOT NULL,
        priority      INTEGER DEFAULT 0,
        retry_count   INTEGER DEFAULT 0,
        status        TEXT DEFAULT 'pending',
        error_message TEXT,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    // Full API responses keyed by canonical URL
    // Populated automatically by the interceptor on every GET
    await db.execute('''
      CREATE TABLE IF NOT EXISTS response_cache (
        url_key    TEXT PRIMARY KEY,
        entity     TEXT NOT NULL,
        raw        TEXT NOT NULL,
        cached_at  TEXT NOT NULL,
        expires_at TEXT NOT NULL
      )
    ''');

    // Normalized per-entity records (id → data)
    // Extracted automatically from list/detail responses
    // Single source of truth for each entity instance
    await db.execute('''
      CREATE TABLE IF NOT EXISTS normalized_entities (
        entity       TEXT NOT NULL,
        server_id    TEXT NOT NULL,
        local_id     TEXT,
        data         TEXT NOT NULL,
        is_dirty     INTEGER DEFAULT 0,
        synced_at    TEXT,
        updated_at   TEXT NOT NULL,
        PRIMARY KEY (entity, server_id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_sq_status   ON sync_queue(status, priority DESC, created_at ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rc_entity   ON response_cache(entity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_entity   ON normalized_entities(entity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_dirty    ON normalized_entities(entity, is_dirty)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_local_id ON normalized_entities(local_id)');
  }

  // ══════════════════════════════════════════════
  // SYNC QUEUE
  // ══════════════════════════════════════════════

  Future<void> enqueueSyncOperation(SyncOperation op) async {
    final database = await db;
    await database.insert('sync_queue', op.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    await database.update('sync_queue', op.toMap(), where: 'id = ?', whereArgs: [op.id]);
  }

  Future<void> deleteSyncOperation(String id) async {
    final database = await db;
    await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final database = await db;
    final r = await database.rawQuery(
      "SELECT COUNT(*) c FROM sync_queue WHERE status IN ('pending','failed') AND retry_count < 5",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> getFailedCount() async {
    final database = await db;
    final r = await database.rawQuery("SELECT COUNT(*) c FROM sync_queue WHERE status = 'failed'");
    return (r.first['c'] as int?) ?? 0;
  }

  /// Smart deduplication before sync:
  /// - Multiple updates for same entity+id → keep latest only
  /// - create + delete for same entity_id → cancel both (net-zero)
  Future<void> deduplicateQueue() async {
    final database = await db;

    // Keep only the last pending update per entity+entity_id
    await database.rawDelete('''
      DELETE FROM sync_queue
      WHERE operation = 'update' AND status = 'pending'
        AND id NOT IN (
          SELECT id FROM sync_queue s2
          WHERE s2.operation = 'update' AND s2.status = 'pending'
            AND s2.entity = sync_queue.entity
            AND s2.entity_id = sync_queue.entity_id
          ORDER BY s2.created_at DESC LIMIT 1
        )
    ''');

    // Cancel create+delete pairs
    final pairs = await database.rawQuery('''
      SELECT entity, entity_id FROM sync_queue
      WHERE status = 'pending'
      GROUP BY entity, entity_id
      HAVING SUM(operation='create') > 0 AND SUM(operation='delete') > 0
    ''');
    for (final row in pairs) {
      await database.delete(
        'sync_queue',
        where: "entity=? AND entity_id=? AND status='pending'",
        whereArgs: [row['entity'], row['entity_id']],
      );
    }
  }

  // ══════════════════════════════════════════════
  // RESPONSE CACHE  (URL-keyed full responses)
  // ══════════════════════════════════════════════

  Future<void> cacheResponse(String urlKey, String entity, dynamic data, Duration ttl) async {
    final database = await db;
    await database.insert(
      'response_cache',
      {
        'url_key': urlKey,
        'entity': entity,
        'raw': jsonEncode(data),
        'cached_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(ttl).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> getCachedResponse(String urlKey) async {
    final database = await db;
    final rows = await database.query(
      'response_cache',
      where: 'url_key = ? AND expires_at > ?',
      whereArgs: [urlKey, DateTime.now().toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['raw'] as String);
  }

  /// Invalidate all cached responses whose url_key starts with [pathPrefix].
  Future<void> invalidateCacheByPrefix(String pathPrefix) async {
    final database = await db;
    await database.delete(
      'response_cache',
      where: "url_key = ? OR url_key LIKE ?",
      whereArgs: [pathPrefix, '$pathPrefix?%'],
    );
  }

  Future<void> clearExpiredCache() async {
    final database = await db;
    await database.delete(
      'response_cache',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  // ══════════════════════════════════════════════
  // NORMALIZED ENTITIES  (entity × server_id → data)
  // ══════════════════════════════════════════════

  /// Upsert a normalized entity. Called automatically by the interceptor.
  Future<void> saveNormalized({
    required String entity,
    required String serverId,
    String? localId,
    required Map<String, dynamic> data,
    bool isDirty = false,
  }) async {
    final database = await db;
    await database.insert(
      'normalized_entities',
      {
        'entity': entity,
        'server_id': serverId,
        'local_id': localId,
        'data': jsonEncode(data),
        'is_dirty': isDirty ? 1 : 0,
        'synced_at': isDirty ? null : DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save an offline-only entity (no server_id yet).
  /// Uses localId as the composite key until synced.
  Future<void> saveLocalOnly({
    required String entity,
    required String localId,
    required Map<String, dynamic> data,
  }) async {
    final database = await db;
    await database.insert(
      'normalized_entities',
      {
        'entity': entity,
        'server_id': localId,   // temporary — overwritten after sync
        'local_id': localId,
        'data': jsonEncode(data),
        'is_dirty': 1,
        'synced_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getNormalized(String entity, String id) async {
    final database = await db;
    final rows = await database.query(
      'normalized_entities',
      where: 'entity = ? AND (server_id = ? OR local_id = ?)',
      whereArgs: [entity, id, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      ...jsonDecode(rows.first['data'] as String) as Map<String, dynamic>,
      '_is_dirty': rows.first['is_dirty'] == 1,
      '_local_id': rows.first['local_id'],
    };
  }

  Future<List<Map<String, dynamic>>> getAllNormalized(String entity) async {
    final database = await db;
    final rows = await database.query('normalized_entities', where: 'entity = ?', whereArgs: [entity]);
    return rows.map((r) => {
          ...jsonDecode(r['data'] as String) as Map<String, dynamic>,
          '_is_dirty': r['is_dirty'] == 1,
          '_local_id': r['local_id'],
        }).toList();
  }

  Future<void> markNormalizedSynced(String localId, String serverId, String entity) async {
    final database = await db;
    // Update the temp record with the real server ID
    final rows = await database.query(
      'normalized_entities',
      where: 'entity = ? AND local_id = ?',
      whereArgs: [entity, localId],
    );
    if (rows.isEmpty) return;

    final existing = jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    existing['id'] = serverId;

    await database.delete('normalized_entities', where: 'entity=? AND server_id=?', whereArgs: [entity, localId]);
    await database.insert('normalized_entities', {
      'entity': entity,
      'server_id': serverId,
      'local_id': localId,
      'data': jsonEncode(existing),
      'is_dirty': 0,
      'synced_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteNormalized(String entity, String id) async {
    final database = await db;
    await database.delete(
      'normalized_entities',
      where: 'entity=? AND (server_id=? OR local_id=?)',
      whereArgs: [entity, id, id],
    );
  }

  // ══════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════

  Future<Map<String, int>> getStats() async {
    final database = await db;
    final pending = await getPendingCount();
    final failed = await getFailedCount();
    final r = await database.rawQuery('SELECT COUNT(*) c FROM response_cache WHERE expires_at > ?',
        [DateTime.now().toIso8601String()]);
    final cached = (r.first['c'] as int?) ?? 0;
    final d = await database.rawQuery('SELECT COUNT(*) c FROM normalized_entities WHERE is_dirty=1');
    final dirty = (d.first['c'] as int?) ?? 0;
    return {'pending': pending, 'failed': failed, 'cached_urls': cached, 'dirty_entities': dirty};
  }
}
