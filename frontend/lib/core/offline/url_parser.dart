/// Parses any API URL into (entity, id) without configuration.
///
///   /api/v1/inventory/products         → entity: 'inventory_products',  id: null
///   /api/v1/inventory/products/123     → entity: 'inventory_products',  id: '123'
///   /api/v1/sales/orders/45/items      → entity: 'sales_orders_items',  id: null
///   /api/v1/sales/orders/45/items/7   → entity: 'sales_orders_items',  id: '7'
class UrlParser {
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static ParsedUrl parse(String path) {
    final cleaned = path
        .replaceFirst(RegExp(r'^/api/v\d+/'), '')
        .replaceFirst(RegExp(r'^/v\d+/'), '')
        .replaceFirst(RegExp(r'^/api/'), '')
        .replaceFirst(RegExp(r'^/'), '');

    final segments = cleaned
        .split('/')
        .map((s) => s.split('?').first)
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return const ParsedUrl(entity: 'root', id: null, parentEntity: null);
    }

    // Entity = all non-ID segments joined by '_'
    final entitySegments = segments.where((s) => !_isId(s)).toList();
    final entity = entitySegments.isEmpty ? 'root' : entitySegments.join('_');

    // ID = last segment if it looks like an ID
    final id = _isId(segments.last) ? segments.last : null;

    // Parent entity = entity without its last segment (for sub-resources)
    final parentEntity = entitySegments.length > 1
        ? entitySegments.take(entitySegments.length - 1).join('_')
        : null;

    return ParsedUrl(entity: entity, id: id, parentEntity: parentEntity);
  }

  /// Converts an item URL to its list URL.
  /// /products/123 → /products
  static String listUrlFor(String path) {
    final last = path.split('/').where((s) => s.isNotEmpty).last;
    if (!_isId(last)) return path;
    return path.substring(0, path.lastIndexOf('/$last'));
  }

  /// All cache keys that should be invalidated after a mutation.
  static List<String> invalidationKeys(String method, String path) {
    final parsed = parse(path);
    final keys = <String>{path};

    // Mutating an item → also invalidate its list
    if (parsed.id != null) keys.add(listUrlFor(path));

    // Sub-resource mutation → also invalidate the parent resource URL
    if (parsed.parentEntity != null) {
      final parentPath = _parentResourcePath(path);
      if (parentPath != null) keys.add(parentPath);
    }

    return keys.toList();
  }

  /// Returns the URL of the parent resource for a nested path.
  /// /orders/45/items → /orders/45
  static String? _parentResourcePath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    // Walk backwards past any ID at the end, then past the sub-resource name
    var i = segments.length - 1;
    if (i >= 0 && _isId(segments[i])) i--; // skip trailing id
    if (i >= 0 && !_isId(segments[i])) i--; // skip sub-resource name
    if (i < 0) return null;
    return '/${segments.take(i + 1).join('/')}';
  }

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

  static int inferPriority(String entity, String method) {
    if (entity.contains('auth') || entity.contains('payment')) return 10;
    if (entity.contains('invoice') || entity.contains('order')) return 8;
    if (method == 'DELETE') return 3;
    if (method == 'POST') return 7;
    return 5;
  }

  static bool _isId(String s) {
    if (s.isEmpty) return false;
    if (int.tryParse(s) != null) return true;
    if (_uuidPattern.hasMatch(s)) return true;
    return false;
  }
}

class ParsedUrl {
  final String entity;
  final String? id;
  final String? parentEntity;

  const ParsedUrl({required this.entity, required this.id, required this.parentEntity});

  bool get isList => id == null;
  bool get isItem => id != null;

  @override
  String toString() => 'ParsedUrl(entity: $entity, id: $id)';
}
