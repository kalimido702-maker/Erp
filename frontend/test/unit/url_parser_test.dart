import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/core/offline/url_parser.dart';

void main() {
  group('UrlParser.parse', () {
    test('parses list endpoint', () {
      final result = UrlParser.parse('/api/v1/inventory/products');
      expect(result.entity, 'inventory_products');
      expect(result.id, isNull);
      expect(result.isList, isTrue);
    });

    test('parses item endpoint with integer id', () {
      final result = UrlParser.parse('/api/v1/inventory/products/123');
      expect(result.entity, 'inventory_products');
      expect(result.id, '123');
      expect(result.isItem, isTrue);
    });

    test('parses nested sub-resource list', () {
      final result = UrlParser.parse('/api/v1/sales/orders/45/items');
      expect(result.entity, 'sales_orders_items');
      expect(result.id, isNull);
      expect(result.parentEntity, 'sales_orders');
    });

    test('parses nested sub-resource item', () {
      final result = UrlParser.parse('/api/v1/sales/orders/45/items/7');
      expect(result.entity, 'sales_orders_items');
      expect(result.id, '7');
    });

    test('parses uuid as id', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final result = UrlParser.parse('/api/v1/users/$uuid');
      expect(result.entity, 'users');
      expect(result.id, uuid);
    });

    test('handles path without api prefix', () {
      final result = UrlParser.parse('/inventory/products/5');
      expect(result.entity, 'inventory_products');
      expect(result.id, '5');
    });
  });

  group('UrlParser.listUrlFor', () {
    test('strips id from item url', () {
      expect(UrlParser.listUrlFor('/api/v1/products/123'), '/api/v1/products');
    });

    test('returns same url if no id', () {
      expect(UrlParser.listUrlFor('/api/v1/products'), '/api/v1/products');
    });
  });

  group('UrlParser.invalidationKeys', () {
    test('mutation on item invalidates item and list', () {
      final keys = UrlParser.invalidationKeys('PUT', '/api/v1/products/5');
      expect(keys, containsAll(['/api/v1/products/5', '/api/v1/products']));
    });

    test('post to list invalidates list', () {
      final keys = UrlParser.invalidationKeys('POST', '/api/v1/products');
      expect(keys, contains('/api/v1/products'));
    });
  });

  group('UrlParser.inferTtl', () {
    test('volatile entities get 10 minute ttl', () {
      expect(UrlParser.inferTtl('attendance'), const Duration(minutes: 10));
      expect(UrlParser.inferTtl('dashboard'), const Duration(minutes: 10));
    });

    test('medium entities get 30 minute ttl', () {
      expect(UrlParser.inferTtl('invoice'), const Duration(minutes: 30));
    });

    test('stable entities get 6 hour ttl', () {
      expect(UrlParser.inferTtl('products'), const Duration(hours: 6));
    });
  });
}
