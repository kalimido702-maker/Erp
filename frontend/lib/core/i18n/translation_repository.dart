import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_assets.dart';
import 'app_locale.dart';

/// Loads UI translation strings using a 3-layer, offline-first strategy:
///
/// ```
/// bundled assets   (always present → app is usable offline on first launch)
///      ⊕ cached    (last good copy fetched from the backend, persisted)
///      ⊕ remote    (live, tenant-aware overrides from the backend)   ← wins
/// ```
///
/// Each layer is merged over the previous, so a missing remote key transparently
/// falls back to the cached, then the bundled value, then the key itself.
class TranslationRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  TranslationRepository(this._dio, this._prefs);

  static const _cachePrefix = 'i18n_cache_';
  static const _manifestEndpoint = '/i18n/manifest';
  String _localeEndpoint(String code) => '/i18n/$code';

  // ── Layer 1: bundled defaults ─────────────────────────────────────────────
  Future<Map<String, String>> loadBundled(AppLocale locale) async {
    try {
      final raw = await rootBundle.loadString(AppAssets.i18nBundle(locale.code));
      return _flatten(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return {};
    }
  }

  // ── Layer 2: persisted cache ──────────────────────────────────────────────
  Map<String, String> loadCached(AppLocale locale) {
    final raw = _prefs.getString('$_cachePrefix${locale.code}');
    if (raw == null) return {};
    try {
      return _flatten(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(AppLocale locale, Map<String, dynamic> json) async {
    await _prefs.setString('$_cachePrefix${locale.code}', jsonEncode(json));
  }

  // ── Layer 3: live remote (best-effort) ────────────────────────────────────
  /// Fetches tenant-aware strings from the backend and refreshes the cache.
  /// Returns `null` on any failure (offline, 404 before the endpoint exists,
  /// etc.) — callers keep whatever they already merged.
  Future<Map<String, String>?> fetchRemote(AppLocale locale) async {
    try {
      final res = await _dio.get(_localeEndpoint(locale.code));
      final data = _unwrap(res.data);
      if (data is! Map<String, dynamic>) return null;
      await _saveCache(locale, data);
      return _flatten(data);
    } catch (_) {
      return null;
    }
  }

  /// The locales this tenant actually offers, from the backend manifest.
  /// Falls back to the bundled catalogue when the endpoint is unavailable.
  Future<List<AppLocale>> fetchSupportedLocales() async {
    try {
      final res = await _dio.get(_manifestEndpoint);
      final data = _unwrap(res.data);
      final codes = (data is Map ? data['locales'] : data) as List?;
      final locales = codes
          ?.map((c) => AppLocale.fromCode(c.toString()))
          .toSet()
          .toList();
      if (locales != null && locales.isNotEmpty) return locales;
    } catch (_) {/* fall through */}
    return AppLocale.values;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Unwrap the API envelope `{ success, message, data }` when present.
  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// Flatten nested JSON into dotted keys: `{auth:{login:".."}}` → `auth.login`.
  Map<String, String> _flatten(Map<String, dynamic> json, [String prefix = '']) {
    final out = <String, String>{};
    json.forEach((key, value) {
      final composed = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        out.addAll(_flatten(value, composed));
      } else if (value != null) {
        out[composed] = value.toString();
      }
    });
    return out;
  }
}
