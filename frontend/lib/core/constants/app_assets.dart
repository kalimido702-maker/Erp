/// Single source of truth for every bundled asset path in the app.
///
/// Rules:
/// - NEVER hardcode an `'assets/...'` string anywhere else. Reference [AppAssets].
/// - Logos come in two tones; use [BrandLogo] (below) instead of picking a path
///   by hand so light/dark selection stays in one place.
abstract final class AppAssets {
  AppAssets._();

  static const _images = 'assets/images';
  static const _i18n = 'assets/i18n';

  // ── Brand logos ───────────────────────────────────────────────────────────
  /// Colored شاملX logo — use on light surfaces (sidebar, white cards).
  static const String logoColored = '$_images/shamel_logo.png';

  /// White شاملX logo — use on the brand gradient / dark surfaces.
  static const String logoWhite = '$_images/shamel_logo_white.png';

  /// Square app icon variant.
  static const String logoSquare = '$_images/shamel_logo_square.png';

  // ── i18n bundles (offline-first defaults) ─────────────────────────────────
  static String i18nBundle(String localeCode) => '$_i18n/$localeCode.json';
}
