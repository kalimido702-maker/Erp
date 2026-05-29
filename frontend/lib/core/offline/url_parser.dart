/// Parses any API URL into (entity, id) without any configuration.
///
/// Examples:
///   /api/v1/inventory/products           → entity: 'inventory_products',  id: null
///   /api/v1/inventory/products/123       → entity: 'inventory_products',  id: '123'
///   /api/v1/sales/orders/45/items        → entity: 'sales_order_items',   id: null
///   /api/v1/sales/orders/45/items/7      → entity: 'sales_order_items',   id: '7'
///   /api/v1/auth/login                   → entity: 'auth',                id: null
class UrlParser {
  // UUID v4 pattern
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static ParsedUrl parse(String path) {
    // Strip version prefix: /api/v1/ or /v1/ or /api/
    final cleaned = path
        .replaceFirst(RegExp(r'^/api/v\d+/'), '')
        .replaceFirst(RegExp(r'^/v\d+/'), '')
        .replaceFirst(RegExp(r'^/api/'), '')
        .replaceFirst(RegExp(r'^/'), '');

    final segments = cleaned
        .split('/')
        .map((s) => s.split('?').first) // strip query string if any
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return ParsedUrl(entity: 'root', id: null, parentEntity: null);
    }

    // Walk segments — collect name-segments and id-segments alternately
    final entityParts = <String>[];
    String? resourceId;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (_isId(seg)) {
        resourceId = seg;
        // Next non-id segments become a sub-entity
        // e.g. orders/45/items → entity: orders_items, resourceId stays on items
        resourceId = seg;
      } else {
        if (i > 0 && _isId(segments[i - 1])) {
          // sub-resource after an id: add to entity
          entityParts.add(seg);
          resourceId = null; // reset — id is on sub-resource now
        } else {
          entityParts.add(seg);
        }
      }
    }

    // The last id found is the resource ID
    final lastId = segments.last;
    final actualId = _isId(lastId) ? lastId : null;

    // Entity name: all non-id segments joined by _
    final entitySegments = segments.where((s) => !_isId(s)).toList();
    final entity = entitySegments.join('_');

    // Parent entity: for sub-resources (e.g. orders_items → orders)
    final parentEntity = entitySegments.length > 1
        ? entitySegments.take(entitySegments.length - 1).join('_')
        : null;

    return ParsedUrl(
      entity: entity.isEmpty ? 'root' : entity,
      id: actualId,
      parentEntity: parentEntity,
    );
  }

  /// Returns the list URL for a given item URL.
  /// /products/123 → /products
  static String listUrlFor(String itemPath) {
    final lastSlash = itemPath.lastIndexOf('/');
    if (lastSlash <= 0) return itemPath;
    final last = itemPath.substring(lastSlash + 1);
    return _isId(last) ? itemPath.substring(0, lastSlash) : itemPath;
  }

  /// Returns all cache keys that should be invalidated after a mutation on path.
  static List<String> invalidationKeys(String method, String path) {
    final parsed = parse(path);
    final keys = <String>{path};

    if (parsed.id != null) {
      // Invalidate both the item AND its list
      keys.add(listUrlFor(path));
    }

    if (parsed.parentEntity != null) {
      // Invalidate parent list too (e.g. sales_orders list when order_items change)
      final parentPath = path.substring(0, _parentPathEnd(path));
      keys.add(parentPath);
    }

    return keys.toList();
  }

  static int _parentPathEnd(String path) {
    final segments = path.split('/');
    // Find second-to-last non-id segment end
    var count = 0;
    for (var i = segments.length - 1; i >= 0; i--) {
      if (!_isId(segments[i])) {
        count++;
        if (count == 2) return segments.take(i + 1).join('/').length;
      }
    }
    return path.length;
  }

  static bool _isId(String s) {
    if (s.isEmpty) return false;
    if (int.tryParse(s) != null) return true;
    if (_uuidPattern.hasMatch(s)) return true;
    return false;
  }

  /// Infer a smart TTL based on the entity type.
  static Duration inferTtl(String entity) {
    const volatile = {'attendance', 'stock_movement', 'notification', 'dashboard'};
    const medium = {'order', 'invoice', 'transaction', 'report'};

    for (final v in volatile) {
      if (entity.contains(v)) return const Duration(minutes: 10);
    }
    for (final m in medium) {
      if (entity.contains(m)) return const Duration(minutes: 30);
    }
    return const Duration(hours: 6);
  }

  /// Infer auto-priority for sync queue from entity + method.
  static int inferPriority(String entity, String method) {
    if (entity.contains('auth') || entity.contains('payment')) return 10;
    if (entity.contains('invoice') || entity.contains('order')) return 8;
    if (method == 'DELETE') return 3;
    if (method == 'POST') return 7;
    return 5;
  }
}

class ParsedUrl {
  final String entity;
  final String? id;
  final String? parentEntity;

  const ParsedUrl({
    required this.entity,
    required this.id,
    required this.parentEntity,
  });

  bool get isList => id == null;
  bool get isItem => id != null;

  @override
  String toString() => 'ParsedUrl(entity: $entity, id: $id)';
}
