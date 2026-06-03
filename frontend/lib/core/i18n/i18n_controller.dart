import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';
import 'app_locale.dart';
import 'translation_repository.dart';

/// Provided by an override in `main()` after `SharedPreferences.getInstance()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository(
    ref.read(apiClientProvider).dio,
    ref.read(sharedPreferencesProvider),
  );
});

/// Immutable snapshot of the app's localization state.
class I18nState {
  final AppLocale locale;
  final List<AppLocale> supportedLocales;
  final Map<String, String> strings;
  final bool ready;

  const I18nState({
    required this.locale,
    required this.supportedLocales,
    required this.strings,
    required this.ready,
  });

  I18nState copyWith({
    AppLocale? locale,
    List<AppLocale>? supportedLocales,
    Map<String, String>? strings,
    bool? ready,
  }) {
    return I18nState(
      locale: locale ?? this.locale,
      supportedLocales: supportedLocales ?? this.supportedLocales,
      strings: strings ?? this.strings,
      ready: ready ?? this.ready,
    );
  }

  /// Look up a key, interpolating `{placeholders}` from [args].
  /// Missing keys return the key itself (so gaps are visible, never crash).
  String translate(String key, {Map<String, String>? args}) {
    var value = strings[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }
}

final i18nControllerProvider =
    NotifierProvider<I18nController, I18nState>(I18nController.new);

/// Owns the current locale and the merged translation table. Drives both the
/// app's `Locale`/`Directionality` and every `context.tr(...)` lookup.
class I18nController extends Notifier<I18nState> {
  TranslationRepository get _repo => ref.read(translationRepositoryProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  I18nState build() {
    final saved = AppLocale.fromCode(_prefs.getString(AppConstants.localeKey));
    // Kick off async bundle/cache/remote loading without blocking first frame.
    Future.microtask(_bootstrap);
    return I18nState(
      locale: saved,
      supportedLocales: AppLocale.values,
      strings: const {},
      ready: false,
    );
  }

  Future<void> _bootstrap() async {
    await _loadFor(state.locale, refreshRemote: true);
    final supported = await _repo.fetchSupportedLocales();
    state = state.copyWith(supportedLocales: supported);
  }

  /// Merge bundled + cached immediately (offline-ready), then layer live remote
  /// strings on top when reachable.
  Future<void> _loadFor(AppLocale locale, {required bool refreshRemote}) async {
    final bundled = await _repo.loadBundled(locale);
    final cached = _repo.loadCached(locale);
    state = state.copyWith(
      locale: locale,
      strings: {...bundled, ...cached},
      ready: true,
    );

    if (refreshRemote) {
      final remote = await _repo.fetchRemote(locale);
      if (remote != null) {
        state = state.copyWith(strings: {...bundled, ...cached, ...remote});
      }
    }
  }

  /// Switch language. Persists the choice and reloads the table; the UI (and
  /// text direction) updates reactively for every watcher of this provider.
  Future<void> setLocale(AppLocale locale) async {
    if (locale == state.locale && state.ready) return;
    await _prefs.setString(AppConstants.localeKey, locale.code);
    await _loadFor(locale, refreshRemote: true);
  }

  /// Convenience toggle between the two primary languages.
  Future<void> toggle() async {
    await setLocale(state.locale == AppLocale.ar ? AppLocale.en : AppLocale.ar);
  }
}
