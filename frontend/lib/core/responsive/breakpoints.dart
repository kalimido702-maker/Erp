/// Central responsive breakpoints. Change them here once — never sprinkle magic
/// width numbers across widgets.
abstract final class Breakpoints {
  Breakpoints._();

  /// < [mobile]            → phones
  /// [mobile]..[tablet]    → tablets / small windows
  /// >= [tablet]           → desktop / wide web
  static const double mobile = 600;
  static const double tablet = 1024;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}

/// The three logical form factors the UI adapts to.
enum FormFactor { mobile, tablet, desktop }

FormFactor formFactorOf(double width) {
  if (Breakpoints.isMobile(width)) return FormFactor.mobile;
  if (Breakpoints.isTablet(width)) return FormFactor.tablet;
  return FormFactor.desktop;
}
