import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

export 'breakpoints.dart';

/// Picks a widget per form factor. `tablet`/`desktop` fall back to the next
/// smaller one when omitted, so most callers only provide `mobile` + `desktop`.
///
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileLoginView(),
///   desktop: WebLoginView(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (formFactorOf(constraints.maxWidth)) {
          case FormFactor.desktop:
            return desktop ?? tablet ?? mobile;
          case FormFactor.tablet:
            return tablet ?? desktop ?? mobile;
          case FormFactor.mobile:
            return mobile;
        }
      },
    );
  }
}

/// Ergonomic responsive queries off `BuildContext`. Uses `MediaQuery` width, so
/// it reflects the window — not a parent box. For box-relative decisions use
/// [ResponsiveLayout] / `LayoutBuilder` directly.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  FormFactor get formFactor => formFactorOf(screenWidth);

  bool get isMobile => formFactor == FormFactor.mobile;
  bool get isTablet => formFactor == FormFactor.tablet;
  bool get isDesktop => formFactor == FormFactor.desktop;

  /// Resolve a value per form factor with graceful fallback.
  /// `context.responsive(mobile: 16, desktop: 24)`
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    switch (formFactor) {
      case FormFactor.desktop:
        return desktop ?? tablet ?? mobile;
      case FormFactor.tablet:
        return tablet ?? desktop ?? mobile;
      case FormFactor.mobile:
        return mobile;
    }
  }
}
