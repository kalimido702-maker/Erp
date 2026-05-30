/// Recursively sanitizes a payload so it can always be safely passed to jsonEncode.
///
/// Problem: Dio payloads may contain DateTime, enums, custom objects, or nested
/// structures that cause `jsonEncode` to throw `JsonUnsupportedObjectError` at runtime.
///
/// This runs before storing to sync_queue and before sending API requests.
Map<String, dynamic> sanitizePayload(Map<String, dynamic>? raw) {
  if (raw == null) return {};
  return _sanitizeMap(raw);
}

Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
  return map.map((key, value) => MapEntry(key, _sanitizeValue(value)));
}

dynamic _sanitizeValue(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value;
  if (value is bool) return value;

  // DateTime → ISO 8601 string
  if (value is DateTime) return value.toIso8601String();

  // Enum → name string
  if (value is Enum) return value.name;

  // Nested map
  if (value is Map<String, dynamic>) return _sanitizeMap(value);
  if (value is Map) return _sanitizeMap(Map<String, dynamic>.from(value));

  // List — sanitize each element
  if (value is List) return value.map(_sanitizeValue).toList();

  // Fallback: toString() — never throws, always serializable
  return value.toString();
}
