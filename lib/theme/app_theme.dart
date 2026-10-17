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
  static ThemeData getTheme(Color seed, Color background) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    // Use the exact chosen color as the primary (not the M3 tonal variant),
    // so the banner/buttons match what the user picked.
    final onPrimary = ThemeData.estimateBrightnessForColor(seed) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    final scheme = base.copyWith(
      primary: seed,
      onPrimary: onPrimary,
      surface: Colors.white,
      onSurface: const Color(0xFF0F172A),
      outline: const Color(0xFFE2E8F0),
      outlineVariant: const Color(0xFFE2E8F0),
    );
    final tokens = AppTokens.fromScheme(scheme, pageBg: background);

    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: tokens.textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: tokens.textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: tokens.textMuted,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: tokens.textMuted,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 11,
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
          fontSize: 20,
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
          fontSize: 14,
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
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.headerBg,
        contentTextStyle:
            GoogleFonts.poppins(color: tokens.headerFg, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
