import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import 'i18n_controller.dart';
import 'localized_value.dart';

/// Exposes the current [I18nState] to the whole widget tree so that
/// `context.tr('key')` works from any widget — Consumer or not — and rebuilds
/// dependents automatically when the language changes.
///
/// Placed once at the app root (see `ErpApp`), fed by `i18nControllerProvider`.
class TranslationsScope extends InheritedWidget {
  final I18nState state;

  const TranslationsScope({
    super.key,
    required this.state,
    required super.child,
  });

  static I18nState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TranslationsScope>();
    assert(scope != null, 'TranslationsScope is missing above this widget.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(TranslationsScope oldWidget) {
    return oldWidget.state.locale != state.locale ||
        !identical(oldWidget.state.strings, state.strings);
  }
}

/// The ergonomic translation API. Prefer these over touching providers directly.
extension TranslateContext on BuildContext {
  /// Translate a UI key: `context.tr('auth.login')`.
  /// Supports `{placeholder}` interpolation: `context.tr('hi', args: {'name': n})`.
  String tr(String key, {Map<String, String>? args}) =>
      TranslationsScope.of(this).translate(key, args: args);

  /// The active language.
  AppLocale get appLocale => TranslationsScope.of(this).locale;

  /// True when the active language is right-to-left.
  bool get isRtl => appLocale.isRtl;

  /// Resolve a translatable **data** field (e.g. a product name) to the active
  /// language: `context.localized(product.name)`.
  String localized(LocalizedValue value) => value.resolve(appLocale);
}
