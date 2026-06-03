import 'package:flutter/material.dart';

/// شاملX design-system tokens — mirrors shamelx.css exactly.
/// Light/dark variants are separate classes; AppTheme wires them into ThemeData.
abstract class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF0C4FE0);
  static const Color primary600   = Color(0xFF0A41BE);
  static const Color primary700   = Color(0xFF082F8C);
  static const Color primaryTint  = Color(0xFFEAF1FF);
  static const Color primaryTint2 = Color(0xFFDCE8FF);
  static const Color accent       = Color(0xFF12B5F0);
  static const Color accentTint   = Color(0xFFE2F6FF);

  // Status
  static const Color ok       = Color(0xFF15976A);
  static const Color okTint   = Color(0xFFE0F4EC);
  static const Color warn     = Color(0xFFC6820B);
  static const Color warnTint = Color(0xFFFBF0D6);
  static const Color danger     = Color(0xFFD8453C);
  static const Color dangerTint = Color(0xFFFBE7E5);

  // ── Light ──────────────────────────────────────────────────────────────
  static const Color bg         = Color(0xFFEAEEF7);
  static const Color bg2        = Color(0xFFE1E7F4);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color surface2   = Color(0xFFF5F7FC);
  static const Color surface3   = Color(0xFFEDF1F9);
  static const Color border     = Color(0xFFE3E8F2);
  static const Color border2    = Color(0xFFD2DAEA);
  static const Color text       = Color(0xFF0E1730);
  static const Color text2      = Color(0xFF4A5470);
  static const Color text3      = Color(0xFF8A93AC);
  static const Color grip       = Color(0xFFC2CAD9);

  // ── Dark ───────────────────────────────────────────────────────────────
  static const Color bgDark       = Color(0xFF080D1A);
  static const Color bg2Dark      = Color(0xFF0B1224);
  static const Color surfaceDark  = Color(0xFF101A30);
  static const Color surface2Dark = Color(0xFF16213B);
  static const Color surface3Dark = Color(0xFF1D2A48);
  static const Color borderDark   = Color(0xFF243453);
  static const Color border2Dark  = Color(0xFF2E3F63);
  static const Color textDark     = Color(0xFFEAF0FB);
  static const Color text2Dark    = Color(0xFF9AA6C4);
  static const Color text3Dark    = Color(0xFF65728F);
  static const Color gripDark     = Color(0xFF3C4A6B);
  static const Color primaryDark  = Color(0xFF3470FF);
  static const Color accentDark   = Color(0xFF2BC4FF);
  static const Color okDark       = Color(0xFF2FCB8E);
  static const Color warnDark     = Color(0xFFF2B53D);
  static const Color dangerDark   = Color(0xFFFF6E64);

  // ── Brand gradient stops ───────────────────────────────────────────────
  static const List<Color> brandGradientColors = [
    Color(0xFF0C4FE0), Color(0xFF0A3FC0), Color(0xFF0B6BD6), Color(0xFF12B5F0),
  ];
  static const brandGradientStops = [0.0, 0.48, 0.78, 1.3];
  static const brandGradientBegin = Alignment(-0.5, -1.0);
  static const brandGradientEnd   = Alignment(0.5,  1.0);

  static LinearGradient get brandGradient => const LinearGradient(
    colors: brandGradientColors,
    begin: brandGradientBegin,
    end:   brandGradientEnd,
  );

  // ── Module accent colours ──────────────────────────────────────────────
  static const Color moduleSales      = primary;
  static const Color moduleInventory  = accent;
  static const Color modulePurchases  = warn;
  static const Color moduleHr         = Color(0xFF7B5CF0);
  static const Color moduleFinance    = ok;
  static const Color moduleAccounting = Color(0xFF4527A0);

  // Kept for backward-compat references in older code
  static const Color error = danger;
  static const Color sidebarBg = primary700;
  static const Color textSecondary = text2;
}
