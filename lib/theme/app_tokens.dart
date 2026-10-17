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

  /// Card background (white).
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

  factory AppTokens.fromScheme(
    ColorScheme scheme, {
    required Color pageBg,
  }) {
    final onHeader = scheme.onPrimary;
    return AppTokens(
      headerBg: scheme.primary,
      headerFg: onHeader,
      headerMuted: onHeader.withValues(alpha: 0.72),
      headerSurface: onHeader.withValues(alpha: 0.20),
      headerBorder: onHeader.withValues(alpha: 0.45),
      pageBg: pageBg,
      card: Colors.white,
      softSurface: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.10),
        Colors.white,
      ),
      softSurfaceStrong: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.18),
        Colors.white,
      ),
      textPrimary: _textPrimary,
      textMuted: _textMuted,
      border: _border,
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      income: _income,
      expense: _expense,
      warning: _warning,
      incomeOnHeader: Color.lerp(_income, onHeader, 0.30)!,
      expenseOnHeader: Color.lerp(_expense, onHeader, 0.30)!,
      transfer: _transfer,
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
