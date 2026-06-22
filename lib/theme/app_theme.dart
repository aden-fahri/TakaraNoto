import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors ───────────────────────────────────────────────────────────
  static const Color darkPlum          = Color(0xFF381932);
  static const Color deepPlum          = Color(0xFF2A1227);
  static const Color lighterPlum       = Color(0xFF4D2345);
  static const Color selectedPlum      = Color(0xFF632D59);
  static const Color warmCream         = Color(0xFFFFF3E6);
  // Light mode surface tokens — more contrast than v1
  static const Color surfaceHeroLight  = Color(0xFFF0DFC8); // darker cream for depth
  static const Color cardLight         = Color(0xFFFFFFFF);
  static const Color mutedLightPlum    = Color(0xFF7A5570); // darker for readability
  static const Color mutedDarkLavender = Color(0xFFCFAEC9);
  static const Color borderDark        = Color(0xFF5E3256);
  static const Color borderLight       = Color(0xFFE5CEBC); // more defined than v1

  // ─── Status Colors ──────────────────────────────────────────────────────────
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color roseRed      = Color(0xFFF43F5E);
  static const Color amberAccent  = Color(0xFFFBBF24);

  // ─── Theme Builder ──────────────────────────────────────────────────────────
  static ThemeData getTheme(bool isDark) {
    final base = isDark ? _darkBase() : _lightBase();

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 36, fontWeight: FontWeight.w800,
        color: isDark ? warmCream : darkPlum,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20, fontWeight: FontWeight.w700,
        color: isDark ? warmCream : darkPlum,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: isDark ? warmCream : darkPlum,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: isDark ? warmCream : darkPlum,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 13, fontWeight: FontWeight.w400,
        color: isDark ? mutedDarkLavender : mutedLightPlum,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: isDark ? mutedDarkLavender : mutedLightPlum,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: isDark ? mutedDarkLavender : mutedLightPlum,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      // AppBar is replaced by manual PlumBanner on each screen; keep minimal
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkPlum : darkPlum,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, // always light text on plum
        iconTheme: const IconThemeData(color: warmCream),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: warmCream,
        ),
      ),
      // Card theme — border-based in light mode, no shadow
      cardTheme: CardThemeData(
        color: isDark ? lighterPlum : cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(
            color: isDark ? borderDark : borderLight,
            width: 1,
          ),
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
          color: isDark ? mutedDarkLavender : mutedLightPlum,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? lighterPlum : darkPlum,
        contentTextStyle:
            GoogleFonts.poppins(color: warmCream, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      scaffoldBackgroundColor: isDark ? darkPlum : warmCream,
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? lighterPlum : cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? warmCream : darkPlum,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? mutedDarkLavender : mutedLightPlum,
        ),
      ),
    );
  }

  // ─── Private base themes ────────────────────────────────────────────────────
  static ThemeData _darkBase() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkPlum,
        cardColor: lighterPlum,
        primaryColor: warmCream,
        colorScheme: const ColorScheme.dark(
          primary: warmCream,
          secondary: amberAccent,
          surface: lighterPlum,
          error: roseRed,
        ),
      );

  static ThemeData _lightBase() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: warmCream,
        cardColor: cardLight,
        primaryColor: darkPlum,
        colorScheme: const ColorScheme.light(
          primary: darkPlum,
          secondary: amberAccent,
          surface: cardLight,
          error: roseRed,
        ),
      );
}
