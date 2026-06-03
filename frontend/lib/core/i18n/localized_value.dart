import 'app_locale.dart';

/// A piece of **data** (not UI chrome) that carries per-language values — e.g.
/// a product name stored on the backend as `{"ar": "قميص", "en": "Shirt"}`.
///
/// The backend may return such fields either as a translation map OR, when it
/// has already localized for the requested `Accept-Language`, as a plain
/// string. [LocalizedValue.fromJson] handles both shapes, so models can wrap
/// any translatable field uniformly.
class LocalizedValue {
  final Map<String, String> _values;

  const LocalizedValue(this._values);

  const LocalizedValue.empty() : _values = const {};

  /// Accepts:
  /// - `{"ar": "...", "en": "..."}`  → full translation map
  /// - `"already localized"`          → wrapped under the fallback locale
  /// - `null`                         → empty
  factory LocalizedValue.fromJson(dynamic json) {
    if (json == null) return const LocalizedValue.empty();
    if (json is String) {
      return LocalizedValue({AppLocale.fallback.code: json});
    }
    if (json is Map) {
      return LocalizedValue(
        json.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      );
    }
    return LocalizedValue({AppLocale.fallback.code: json.toString()});
  }

  /// Serialize back to a translation map (for writes / sync payloads).
  Map<String, String> toJson() => Map.unmodifiable(_values);

  bool get isEmpty => _values.isEmpty;

  /// Resolve the best string for [locale]:
  /// requested → platform fallback → any available → empty.
  String resolve(AppLocale locale) {
    return _values[locale.code] ??
        _values[AppLocale.fallback.code] ??
        (_values.isNotEmpty ? _values.values.first : '');
  }

  LocalizedValue copyWith(String localeCode, String value) {
    return LocalizedValue({..._values, localeCode: value});
  }

  @override
  String toString() => 'LocalizedValue($_values)';
}
