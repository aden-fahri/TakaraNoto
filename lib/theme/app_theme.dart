import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Builds the app theme from a dynamic accent seed color.
///
/// All component styling derives from [AppTokens] so the whole app re-skins
/// when the user changes the accent color (see `ThemeController`).
class AppTheme {
  // ─── Shape Tokens ───────────────────────────────────────────────────────────
  /// Consistent corner radius for buttons, chips, and toggles.
  /// Kept moderate (not a full pill/capsule) for a cleaner look.
  static const double buttonRadius = 12;

  // ─── Theme Builder ──────────────────────────────────────────────────────────
  static ThemeData getTheme(
    Color seed,
    Color background, {
    bool dark = false,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    // Use the exact chosen color as the primary (not the M3 tonal variant),
    // so the banner/buttons match what the user picked.
    final onPrimary = ThemeData.estimateBrightnessForColor(seed) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    final surface = dark ? const Color(0xFF1E293B) : Colors.white;
    final onSurface = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final outline = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scheme = base.copyWith(
      primary: seed,
      onPrimary: onPrimary,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outline,
    );
    // In dark mode the page background is derived from the user's pick:
    // a subtle tint of their chosen hue over a near-black base.
    final pageBg = dark
        ? Color.lerp(background, const Color(0xFF0B1120), 0.88)!
        : background;
    final tokens = AppTokens.fromScheme(scheme, pageBg: pageBg);

    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: AppText.hero,
        fontWeight: FontWeight.w800,
        color: tokens.textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: AppText.headline,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: AppText.title,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: AppText.subtitle,
        fontWeight: FontWeight.w400,
        color: tokens.textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: AppText.bodyLarge,
        fontWeight: FontWeight.w400,
        color: tokens.textMuted,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: AppText.body,
        fontWeight: FontWeight.w500,
        color: tokens.textMuted,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: AppText.label,
        fontWeight: FontWeight.w500,
        color: tokens.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      fontFamily: 'Poppins',
      textTheme: textTheme,
      scaffoldBackgroundColor: tokens.pageBg,
      // AppBar is replaced by a manual banner on each screen; keep minimal
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: tokens.headerFg),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: AppText.headline,
          fontWeight: FontWeight.w700,
          color: tokens.headerFg,
        ),
      ),
      // Card theme — border-based, no shadow
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      // BottomNav handled by custom PillNavBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: GoogleFonts.poppins(
          color: tokens.textMuted,
          fontSize: AppText.subtitle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: tokens.accent,
          foregroundColor: tokens.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle:
              GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.headerBg,
        contentTextStyle:
            GoogleFonts.poppins(color: tokens.headerFg, fontSize: AppText.bodyLarge),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: AppText.title,
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: AppText.bodyLarge,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
