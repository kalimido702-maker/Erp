import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/offline/payload_sanitizer.dart';

void main() {
  group('sanitizePayload', () {
    test('converts DateTime to ISO8601 string', () {
      final dt = DateTime(2024, 1, 15, 10, 30);
      final result = sanitizePayload({'date': dt});
      expect(result['date'], dt.toIso8601String());
    });

    test('converts nested DateTime', () {
      final dt = DateTime(2024, 6, 1);
      final result = sanitizePayload({
        'order': {'created_at': dt, 'name': 'Test'},
      });
      expect((result['order'] as Map)['created_at'], dt.toIso8601String());
    });

    test('converts list items', () {
      final dt = DateTime(2024, 1, 1);
      final result = sanitizePayload({
        'dates': [dt, 'plain'],
      });
      final dates = result['dates'] as List;
      expect(dates[0], dt.toIso8601String());
      expect(dates[1], 'plain');
    });

    test('keeps primitives unchanged', () {
      final result = sanitizePayload({'name': 'Alice', 'age': 30, 'active': true});
      expect(result['name'], 'Alice');
      expect(result['age'], 30);
      expect(result['active'], true);
    });

    test('handles null input gracefully', () {
      final result = sanitizePayload(null);
      expect(result, isEmpty);
    });

    test('handles empty map', () {
      final result = sanitizePayload({});
      expect(result, isEmpty);
    });
  });
}
