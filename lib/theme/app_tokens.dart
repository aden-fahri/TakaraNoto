import 'package:flutter/material.dart';

/// Semantic, theme-aware color tokens for the whole app.
///
/// All screens read colors from `context.tokens` instead of hardcoded
/// constants, so the accent + background colors picked by the user
/// (presets or custom) instantly re-skin the app.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.headerBg,
    required this.headerFg,
    required this.headerMuted,
    required this.headerSurface,
    required this.headerBorder,
    required this.pageBg,
    required this.card,
    required this.softSurface,
    required this.softSurfaceStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.income,
    required this.expense,
    required this.warning,
    required this.incomeOnHeader,
    required this.expenseOnHeader,
    required this.transfer,
  });

  /// Banner / header background (the accent color).
  final Color headerBg;

  /// Text and icons on the header.
  final Color headerFg;

  /// Muted text on the header (e.g. labels inside banners).
  final Color headerMuted;

  /// Translucent surface for chips/boxes placed on the header.
  final Color headerSurface;

  /// Translucent border for elements placed on the header.
  final Color headerBorder;

  /// Scaffold / page background (user-selectable).
  final Color pageBg;

  /// Card background (white in light mode, dark slate in dark mode).
  final Color card;

  /// Accent-tinted light surface (chips, pills, input fills).
  final Color softSurface;

  /// Stronger accent-tinted surface (selected/active states).
  final Color softSurfaceStrong;

  /// Primary body text (dark slate).
  final Color textPrimary;

  /// Muted/secondary text (slate gray).
  final Color textMuted;

  /// Neutral border (slate).
  final Color border;

  /// Accent color for primary buttons, active states, icons.
  final Color accent;

  /// Text/icons on top of the accent color.
  final Color onAccent;

  /// Status colors.
  final Color income;
  final Color expense;
  final Color warning;

  /// Status colors lightened for use on top of the header/accent background
  /// so they stay distinguishable even when the accent shares their hue.
  final Color incomeOnHeader;
  final Color expenseOnHeader;

  /// Semantic color for wallet transfers.
  final Color transfer;

  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _income = Color(0xFF10B981);
  static const Color _expense = Color(0xFFF43F5E);
  static const Color _warning = Color(0xFFFBBF24);
  static const Color _transfer = Color(0xFF3F51B5);

  /// Dark palette (D6a): brighter status colors and dark surfaces so the
  /// tokens keep the same contrast relationships as in light mode.
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextMuted = Color(0xFF94A3B8);
  static const Color _darkBorder = Color(0xFF334155);
  static const Color _darkIncome = Color(0xFF34D399);
  static const Color _darkExpense = Color(0xFFFB7185);
  static const Color _darkWarning = Color(0xFFFCD34D);
  static const Color _darkTransfer = Color(0xFF818CF8);

  factory AppTokens.fromScheme(
    ColorScheme scheme, {
    required Color pageBg,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final onHeader = scheme.onPrimary;
    final card = isDark ? _darkCard : Colors.white;
    final income = isDark ? _darkIncome : _income;
    final expense = isDark ? _darkExpense : _expense;
    return AppTokens(
      headerBg: scheme.primary,
      headerFg: onHeader,
      headerMuted: onHeader.withValues(alpha: 0.72),
      headerSurface: onHeader.withValues(alpha: 0.20),
      headerBorder: onHeader.withValues(alpha: 0.45),
      pageBg: pageBg,
      card: card,
      softSurface: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.22 : 0.10),
        card,
      ),
      softSurfaceStrong: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.34 : 0.18),
        card,
      ),
      textPrimary: isDark ? _darkTextPrimary : _textPrimary,
      textMuted: isDark ? _darkTextMuted : _textMuted,
      border: isDark ? _darkBorder : _border,
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      income: income,
      expense: expense,
      warning: isDark ? _darkWarning : _warning,
      incomeOnHeader: Color.lerp(income, onHeader, 0.30)!,
      expenseOnHeader: Color.lerp(expense, onHeader, 0.30)!,
      transfer: isDark ? _darkTransfer : _transfer,
    );
  }

  @override
  AppTokens copyWith({
    Color? headerBg,
    Color? headerFg,
    Color? headerMuted,
    Color? headerSurface,
    Color? headerBorder,
    Color? pageBg,
    Color? card,
    Color? softSurface,
    Color? softSurfaceStrong,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? accent,
    Color? onAccent,
    Color? income,
    Color? expense,
    Color? warning,
    Color? incomeOnHeader,
    Color? expenseOnHeader,
    Color? transfer,
  }) {
    return AppTokens(
      headerBg: headerBg ?? this.headerBg,
      headerFg: headerFg ?? this.headerFg,
      headerMuted: headerMuted ?? this.headerMuted,
      headerSurface: headerSurface ?? this.headerSurface,
      headerBorder: headerBorder ?? this.headerBorder,
      pageBg: pageBg ?? this.pageBg,
      card: card ?? this.card,
      softSurface: softSurface ?? this.softSurface,
      softSurfaceStrong: softSurfaceStrong ?? this.softSurfaceStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      incomeOnHeader: incomeOnHeader ?? this.incomeOnHeader,
      expenseOnHeader: expenseOnHeader ?? this.expenseOnHeader,
      transfer: transfer ?? this.transfer,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      headerFg: Color.lerp(headerFg, other.headerFg, t)!,
      headerMuted: Color.lerp(headerMuted, other.headerMuted, t)!,
      headerSurface: Color.lerp(headerSurface, other.headerSurface, t)!,
      headerBorder: Color.lerp(headerBorder, other.headerBorder, t)!,
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      softSurface: Color.lerp(softSurface, other.softSurface, t)!,
      softSurfaceStrong:
          Color.lerp(softSurfaceStrong, other.softSurfaceStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      incomeOnHeader: Color.lerp(incomeOnHeader, other.incomeOnHeader, t)!,
      expenseOnHeader: Color.lerp(expenseOnHeader, other.expenseOnHeader, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

/// Typography scale (D3).
///
/// Screens used to carry 24 different literal `fontSize` values; this scale
/// folds them into 11 named steps. Prefer `AppText.*` over raw numbers so
/// the text hierarchy stays consistent across the app.
abstract final class AppText {
  /// Smallest text (badges, micro captions). Absorbs 8/9/10/10.5.
  static const double micro = 10;

  /// Small labels (chips, captions). Absorbs 11/11.5.
  static const double label = 11;

  /// Main body text / dense tables. Absorbs 12/12.5.
  static const double body = 12;

  /// Slightly larger body (list tiles, small paragraphs). Absorbs 13/13.5.
  static const double bodyLarge = 13;

  /// Sub-headings / button text. Absorbs 14/15.
  static const double subtitle = 14;

  /// Card & dialog titles. Absorbs 16/18.
  static const double title = 16;

  /// Prominent numbers & headings. Absorbs 20/22.
  static const double headline = 20;

  /// Large stat numbers. Absorbs 24/26.
  static const double display = 24;

  /// Extra-large numbers. 28.
  static const double displayLarge = 28;

  /// Primary balances / hero amounts. Absorbs 32/34.
  static const double stat = 32;

  /// App name / hero numerals. Absorbs 36/40.
  static const double hero = 36;
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        AppTokens.fromScheme(
          theme.colorScheme,
          pageBg: theme.scaffoldBackgroundColor,
        );
  }
}
