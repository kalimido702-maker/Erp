import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand
  static const Color primary   = Color(0xFF1565C0); // Deep Blue
  static const Color secondary = Color(0xFF0288D1); // Light Blue
  static const Color accent    = Color(0xFF00BCD4); // Cyan

  // Status
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error   = Color(0xFFC62828);
  static const Color info    = Color(0xFF0277BD);

  // Neutral
  static const Color background   = Color(0xFFF5F7FA);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color border       = Color(0xFFE0E0E0);
  static const Color textPrimary  = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint     = Color(0xFFBDBDBD);

  // Sidebar
  static const Color sidebarBg     = Color(0xFF1A237E);
  static const Color sidebarActive  = Color(0xFF283593);
  static const Color sidebarText   = Color(0xFFE8EAF6);

  // Module colors
  static const Color hrColor          = Color(0xFF7B1FA2);
  static const Color inventoryColor   = Color(0xFF00695C);
  static const Color salesColor       = Color(0xFF1565C0);
  static const Color purchasesColor   = Color(0xFFE65100);
  static const Color financeColor     = Color(0xFF2E7D32);
  static const Color accountingColor  = Color(0xFF4527A0);
}
