import 'package:flutter/widgets.dart';

/// A language the platform can present. The *set* of locales a given tenant
/// actually offers is dynamic (driven by the backend manifest); this enum is
/// just the catalogue of everything we have bundled defaults for.
enum AppLocale {
  ar(code: 'ar', native: 'العربية', english: 'Arabic', direction: TextDirection.rtl),
  en(code: 'en', native: 'English', english: 'English', direction: TextDirection.ltr);

  const AppLocale({
    required this.code,
    required this.native,
    required this.english,
    required this.direction,
  });

  /// BCP-47 language code (`ar`, `en`).
  final String code;

  /// Endonym shown in the language switcher (`العربية`).
  final String native;

  /// English name (`Arabic`).
  final String english;

  /// Writing direction — drives `Directionality` automatically.
  final TextDirection direction;

  bool get isRtl => direction == TextDirection.rtl;

  Locale get locale => Locale(code);

  /// Resolve a code to an [AppLocale], defaulting to [AppLocale.ar].
  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.ar,
    );
  }

  /// The platform's fallback language when a tenant or device asks for one we
  /// don't have. Arabic is the product's primary language.
  static const AppLocale fallback = AppLocale.ar;
}
