import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary, Color hint) {
    final base = GoogleFonts.tajawalTextTheme();
    return base.copyWith(
      displayLarge:  base.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: primary),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: primary),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w800, color: primary),
      headlineMedium:base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: primary),
      titleLarge:    base.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
      titleMedium:   base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: primary),
      bodyLarge:     base.bodyLarge?.copyWith(color: primary),
      bodyMedium:    base.bodyMedium?.copyWith(color: secondary),
      bodySmall:     base.bodySmall?.copyWith(color: hint),
      labelLarge:    base.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
    );
  }

  static ThemeData get light {
    final cs = ColorScheme(
      brightness:       Brightness.light,
      primary:          AppColors.primary,
      onPrimary:        Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primary700,
      secondary:        AppColors.accent,
      onSecondary:      Colors.white,
      secondaryContainer: AppColors.accentTint,
      onSecondaryContainer: AppColors.primary700,
      error:            AppColors.danger,
      onError:          Colors.white,
      surface:          AppColors.surface,
      onSurface:        AppColors.text,
      surfaceContainerHighest: AppColors.surface3,
      outline:          AppColors.border,
      outlineVariant:   AppColors.border2,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme:               _textTheme(AppColors.text, AppColors.text2, AppColors.text3),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.text3, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: AppColors.text2, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppColors.border2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        labelStyle: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  static ThemeData get dark {
    final cs = ColorScheme(
      brightness:       Brightness.dark,
      primary:          AppColors.primaryDark,
      onPrimary:        Colors.white,
      primaryContainer: const Color(0x293470FF),
      onPrimaryContainer: AppColors.primaryTint,
      secondary:        AppColors.accentDark,
      onSecondary:      Colors.white,
      secondaryContainer: const Color(0x242BC4FF),
      onSecondaryContainer: AppColors.accentTint,
      error:            AppColors.dangerDark,
      onError:          Colors.white,
      surface:          AppColors.surfaceDark,
      onSurface:        AppColors.textDark,
      surfaceContainerHighest: AppColors.surface3Dark,
      outline:          AppColors.borderDark,
      outlineVariant:   AppColors.border2Dark,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: _textTheme(AppColors.textDark, AppColors.text2Dark, AppColors.text3Dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderDark, thickness: 1, space: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Dark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.text3Dark, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: AppColors.text2Dark, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
    );
  }
}
