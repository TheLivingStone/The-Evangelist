import 'package:flutter/material.dart';

/// The Evangelist brand theme. Colors come from Product.md / prototype.html.
/// Mission · Movement · Boldness · Action — dark-first, orange accent.
class AppColors {
  static const accent = Color(0xFFFF6B00);
  static const accent2 = Color(0xFFFF8A2B);
  static const green = Color(0xFF34D17E);
  static const blue = Color(0xFF5B8DEF);
  static const purple = Color(0xFF8B83FF);
  static const pink = Color(0xFFF25C9A);

  // dark
  static const dBg = Color(0xFF0A0A0C);
  static const dSurface = Color(0xFF15151A);
  static const dSurface2 = Color(0xFF1E1E25);
  static const dText = Color(0xFFFFFFFF);
  static const dMuted = Color(0xFF8C8C96);

  // light
  static const lBg = Color(0xFFF6F6F3);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurface2 = Color(0xFFF0F0EC);
  static const lText = Color(0xFF1A1A18);
  static const lMuted = Color(0xFF6E6E66);
}

class AppTheme {
  static ThemeData _base(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? AppColors.dBg : AppColors.lBg;
    final surface = dark ? AppColors.dSurface : AppColors.lSurface;
    final text = dark ? AppColors.dText : AppColors.lText;
    final muted = dark ? AppColors.dMuted : AppColors.lMuted;

    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accent2,
      onSecondary: Colors.white,
      error: const Color(0xFFE5484D),
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFECECE6),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.dSurface2 : AppColors.lSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: muted),
      ),
      textTheme: Typography.material2021().white.apply(
            bodyColor: text,
            displayColor: text,
          ).merge(
            TextTheme(bodyMedium: TextStyle(color: text)),
          ),
      dividerColor: dark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE0E0D8),
    );
  }

  static ThemeData get dark => _base(Brightness.dark);
  static ThemeData get light => _base(Brightness.light);
}
