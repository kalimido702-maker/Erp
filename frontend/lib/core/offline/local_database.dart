import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'field_encryptor.dart';
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

  Future<void> _onCreate(Database db, int version) => _createSchema(db);

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final t in ['sync_queue', 'entity_cache', 'local_entities', 'response_cache', 'normalized_entities']) {
        await db.execute('DROP TABLE IF EXISTS $t');
      }
      await _createSchema(db);
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id            TEXT PRIMARY KEY,
        entity        TEXT NOT NULL,
        entity_id     TEXT NOT NULL,
        operation     TEXT NOT NULL,
        method        TEXT NOT NULL,
        endpoint      TEXT NOT NULL,
        payload       TEXT NOT NULL,       -- AES-encrypted JSON
        priority      INTEGER DEFAULT 0,
        retry_count   INTEGER DEFAULT 0,
        status        TEXT DEFAULT 'pending',
        error_message TEXT,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS response_cache (
        url_key    TEXT PRIMARY KEY,
        entity     TEXT NOT NULL,
        raw        TEXT NOT NULL,          -- AES-encrypted JSON
        cached_at  TEXT NOT NULL,
        expires_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS normalized_entities (
        entity       TEXT NOT NULL,
        server_id    TEXT NOT NULL,
        local_id     TEXT,
        data         TEXT NOT NULL,        -- AES-encrypted JSON
        is_dirty     INTEGER DEFAULT 0,
        synced_at    TEXT,
        cached_at    TEXT NOT NULL,        -- for TTL cleanup
        expires_at   TEXT NOT NULL,        -- Fix #8: prevents unbounded growth
        updated_at   TEXT NOT NULL,
        PRIMARY KEY (entity, server_id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_sq_status   ON sync_queue(status, priority DESC, created_at ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rc_entity   ON response_cache(entity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_entity   ON normalized_entities(entity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_dirty    ON normalized_entities(entity, is_dirty)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_local_id ON normalized_entities(local_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ne_expires  ON normalized_entities(expires_at)');
  }

  // ══════════════════════════════════════════════
  // SYNC QUEUE
  // ══════════════════════════════════════════════

  Future<void> enqueueSyncOperation(SyncOperation op) async {
    final database = await db;
    final row = op.toMap();
    // Encrypt payload before storage
    row['payload'] = FieldEncryptor.instance.encrypt(row['payload'] as String);
    await database.insert('sync_queue', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncOperation>> getPendingOperations() async {
    final database = await db;
    final rows = await database.query(
      'sync_queue',
      where: "status IN ('pending', 'failed') AND retry_count < 5",
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map((r) {
      final decrypted = Map<String, dynamic>.from(r);
      decrypted['payload'] = FieldEncryptor.instance.decrypt(r['payload'] as String);
      return SyncOperation.fromMap(decrypted);
    }).toList();
  }

  Future<void> updateSyncOperation(SyncOperation op) async {
    final database = await db;
    final row = op.toMap();
    row['payload'] = FieldEncryptor.instance.encrypt(row['payload'] as String);
    await database.update('sync_queue', row, where: 'id = ?', whereArgs: [op.id]);
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

  Future<void> deduplicateQueue() async {
    final database = await db;

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
  // RESPONSE CACHE
  // ══════════════════════════════════════════════

  Future<void> cacheResponse(String urlKey, String entity, dynamic data, Duration ttl) async {
    final database = await db;
    final encryptedRaw = FieldEncryptor.instance.encryptJson(data);
    await database.insert(
      'response_cache',
      {
        'url_key': urlKey,
        'entity': entity,
        'raw': encryptedRaw,
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
    return FieldEncryptor.instance.decryptJson(rows.first['raw'] as String);
  }

  /// Fix #5: Escape SQLite LIKE special chars (% _ \) in the prefix
  /// so URL segments containing '_' don't act as wildcards.
  Future<void> invalidateCacheByPrefix(String pathPrefix) async {
    final database = await db;
    final escaped = _escapeLike(pathPrefix);
    await database.rawDelete(
      "DELETE FROM response_cache WHERE url_key = ? OR url_key LIKE ? ESCAPE '\\'",
      [pathPrefix, '$escaped?%'],
    );
  }

  /// Escapes `%`, `_`, and `\` in a LIKE pattern operand.
  String _escapeLike(String s) => s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  Future<void> clearExpiredCache() async {
    final database = await db;
    await database.delete('response_cache', where: 'expires_at < ?', whereArgs: [DateTime.now().toIso8601String()]);
  }

  // ══════════════════════════════════════════════
  // NORMALIZED ENTITIES
  // ══════════════════════════════════════════════

  Future<void> saveNormalized({
    required String entity,
    required String serverId,
    String? localId,
    required Map<String, dynamic> data,
    bool isDirty = false,
    Duration ttl = const Duration(days: 7),
  }) async {
    final database = await db;
    final encryptedData = FieldEncryptor.instance.encryptJson(data);
    await database.insert(
      'normalized_entities',
      {
        'entity': entity,
        'server_id': serverId,
        'local_id': localId,
        'data': encryptedData,
        'is_dirty': isDirty ? 1 : 0,
        'synced_at': isDirty ? null : DateTime.now().toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(ttl).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveLocalOnly({
    required String entity,
    required String localId,
    required Map<String, dynamic> data,
  }) async {
    // Local-only records never expire — they persist until synced or explicitly deleted
    await saveNormalized(
      entity: entity,
      serverId: localId,
      localId: localId,
      data: data,
      isDirty: true,
      ttl: const Duration(days: 365),
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
    final data = FieldEncryptor.instance.decryptJson(rows.first['data'] as String) as Map<String, dynamic>;
    return {...data, '_is_dirty': rows.first['is_dirty'] == 1, '_local_id': rows.first['local_id']};
  }

  Future<List<Map<String, dynamic>>> getAllNormalized(String entity) async {
    final database = await db;
    final rows = await database.query('normalized_entities', where: 'entity = ?', whereArgs: [entity]);
    return rows.map((r) {
      final data = FieldEncryptor.instance.decryptJson(r['data'] as String) as Map<String, dynamic>;
      return {...data, '_is_dirty': r['is_dirty'] == 1, '_local_id': r['local_id']};
    }).toList();
  }

  Future<void> markNormalizedSynced(String localId, String serverId, String entity) async {
    final database = await db;
    final rows = await database.query(
      'normalized_entities',
      where: 'entity = ? AND local_id = ?',
      whereArgs: [entity, localId],
    );
    if (rows.isEmpty) return;

    final existing = FieldEncryptor.instance.decryptJson(rows.first['data'] as String) as Map<String, dynamic>;
    existing['id'] = serverId;

    await database.delete('normalized_entities', where: 'entity=? AND server_id=?', whereArgs: [entity, localId]);
    await saveNormalized(entity: entity, serverId: serverId, localId: localId, data: existing);
  }

  Future<void> deleteNormalized(String entity, String id) async {
    final database = await db;
    await database.delete(
      'normalized_entities',
      where: 'entity=? AND (server_id=? OR local_id=?)',
      whereArgs: [entity, id, id],
    );
  }

  /// Fix #8: Remove normalized_entities that have expired AND are not dirty.
  /// Run periodically (e.g., on app start) to keep DB size bounded.
  Future<int> cleanExpiredNormalized() async {
    final database = await db;
    return database.delete(
      'normalized_entities',
      where: "is_dirty = 0 AND expires_at < ?",
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  // ══════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════

  Future<Map<String, int>> getStats() async {
    final database = await db;
    final pending = await getPendingCount();
    final failed = await getFailedCount();
    final rc = await database.rawQuery("SELECT COUNT(*) c FROM response_cache WHERE expires_at > ?", [DateTime.now().toIso8601String()]);
    final ne = await database.rawQuery("SELECT COUNT(*) c FROM normalized_entities WHERE is_dirty=1");
    return {
      'pending': pending,
      'failed': failed,
      'cached_urls': (rc.first['c'] as int?) ?? 0,
      'dirty_entities': (ne.first['c'] as int?) ?? 0,
    };
  }
}
