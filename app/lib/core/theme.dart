import 'package:flutter/material.dart';

/// Shared spacing, radius, and surface tokens for the "Bold Refined" design
/// direction: one bold orange moment (the streak), everything else calm and
/// spacious with hairline borders. Screens compose these instead of hard-coding
/// magic numbers, which is what keeps the whole app visually consistent.
class Dims {
  // 4-pt spacing scale. Use these for gaps/padding everywhere.
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 28;

  // Corner radii. Cards are soft but not pill-round.
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 18;
  static const double rPill = 999;

  // Hairline border — the signature of the refined half of the system. Kept at
  // ~0.6px so it reads as a crisp edge on retina, not a heavy frame.
  static const double hairline = 0.6;

  /// The hairline border colour for the current brightness.
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE6E6DF);

  /// A muted on-surface colour for secondary text, theme-aware.
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
}

/// Reusable building blocks for the Bold Refined look. Static so any screen can
/// call e.g. `Surfaces.card(context, child: ...)` and get a consistent
/// hairline-bordered container without repeating decoration boilerplate.
class Surfaces {
  /// The standard hairline-bordered surface card (the calm/“B” container).
  static Widget card(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(Dims.l),
    VoidCallback? onTap,
  }) {
    final decorated = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Dims.rMd),
        border: Border.all(color: Dims.border(context), width: Dims.hairline),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Dims.rMd),
        onTap: onTap,
        child: decorated,
      ),
    );
  }

  /// A small all-caps section label, e.g. "TUESDAY · JUNE 25".
  static Widget overline(BuildContext context, String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: Dims.muted(context),
    ),
  );

  /// A leading rounded "icon chip" used in grouped action rows.
  static Widget iconChip(BuildContext context, IconData icon, Color tint) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Dims.rSm),
        ),
        child: Icon(icon, size: 18, color: tint),
      );
}

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
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dims.rMd),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE6E6DF),
            width: Dims.hairline,
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
      textTheme: Typography.material2021().white
          .apply(bodyColor: text, displayColor: text)
          .merge(TextTheme(bodyMedium: TextStyle(color: text))),
      dividerColor: dark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE0E0D8),
    );
  }

  // ThemeData construction is relatively expensive. These immutable instances
  // are reused across every mode change instead of rebuilding both themes.
  static final ThemeData dark = _base(Brightness.dark);
  static final ThemeData light = _base(Brightness.light);
}
