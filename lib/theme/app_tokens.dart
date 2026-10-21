import 'package:flutter/material.dart';

enum ThemePalette { plum, teal, custom }

/// Semantic, theme-aware color tokens for the whole app.
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
    required this.chip,
    required this.nav,
    required this.persik,
    required this.lunasBg,
    required this.lunasFg,
    required this.telatBg,
    required this.telatFg,
    required this.cicilBg,
    required this.cicilFg,
    required this.onPersik,
    required this.incomeOnPersik,
    required this.expenseOnPersik,
  });

  final Color headerBg;
  final Color headerFg;
  final Color headerMuted;
  final Color headerSurface;
  final Color headerBorder;
  final Color pageBg;
  final Color card;
  final Color softSurface;
  final Color softSurfaceStrong;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color income;
  final Color expense;
  final Color warning;
  final Color incomeOnHeader;
  final Color expenseOnHeader;
  final Color transfer;
  final Color chip;
  final Color nav;
  final Color persik;
  final Color lunasBg;
  final Color lunasFg;
  final Color telatBg;
  final Color telatFg;
  final Color cicilBg;
  final Color cicilFg;
  final Color onPersik;
  final Color incomeOnPersik;
  final Color expenseOnPersik;

  // ─── Plum Klasik ───────────────────────────────────────────────────────────
  static const _plumLight = <String, Color>{
    'hd': Color(0xFF381932),
    'pg': Color(0xFFFFF3E6),
    'card': Color(0xFFFFFFFF),
    'bd': Color(0xFFF0E4D6),
    'tx': Color(0xFF2A1426),
    'mu': Color(0xFF6B5A68),
    'inc': Color(0xFF047857),
    'exp': Color(0xFFBE123C),
    'ac': Color(0xFF381932),
    'onac': Color(0xFFFFFFFF),
    'soft': Color(0xFFF4ECEF),
    'chip': Color(0xFF52294A),
    'nav': Color(0xFFFFFFFF),
    'persik': Color(0xFFF4C99A),
    'transfer': Color(0xFF3F51B5),
    // Baris atas header (mockup Main.dc.html §2).
    'hdm': Color(0xFFE7CFE0),
    // Teks utama di atas kartu persik (mockup: #2A1426 di kedua tema).
    'onPersik': Color(0xFF2A1426),
  };
  static const _plumDark = <String, Color>{
    'hd': Color(0xFF2B1530),
    'pg': Color(0xFF1D1020),
    'card': Color(0xFF2A1A2E),
    'bd': Color(0xFF4A3050),
    'tx': Color(0xFFF6EEF4),
    'mu': Color(0xFFB7A3B5),
    'inc': Color(0xFF5EE0A8),
    'exp': Color(0xFFFF8FA3),
    'ac': Color(0xFFF4C99A),
    'onac': Color(0xFF2A1426),
    'soft': Color(0xFF382340),
    'chip': Color(0xFF4A2A50),
    'nav': Color(0xFF2A1A2E),
    'persik': Color(0xFFF4C99A),
    // Mockup gelap memakai #A9A4FF (indigo terang) untuk baris transfer.
    'transfer': Color(0xFFA9A4FF),
    // Baris atas header gelap (mockup Dashboard-gelap.dc.html).
    'hdm': Color(0xFFD9C3D6),
    'onPersik': Color(0xFF2A1426),
  };

  // ─── Teal ───────────────────────────────────────────────────────────────────
  static const _tealLight = <String, Color>{
    'hd': Color(0xFF0F3D3A),
    'pg': Color(0xFFF3F1EB),
    'card': Color(0xFFFBFAF7),
    'bd': Color(0xFFE3DFD3),
    'tx': Color(0xFF0B2B2A),
    'mu': Color(0xFF5E6F6C),
    'inc': Color(0xFF047857),
    'exp': Color(0xFFBE123C),
    'ac': Color(0xFF10B981),
    // onac hasil koreksi kontras, bukan dari desain.md (§3.2 tidak menetapkan onac).
    'onac': Color(0xFF0B2B2A),
    'soft': Color(0xFFE8EFEC),
    'chip': Color(0xFF1C5A55),
    'nav': Color(0xFFFBFAF7), // pakai card sampai HTML mockup datang
    'persik': Color(0xFFF2D3A0),
    'transfer': Color(0xFF3F51B5),
    // Kartu persik tetap terang di tema Teal, jadi teksnya gelap (tx Teal).
    'onPersik': Color(0xFF0B2B2A),
  };
  // PROVISIONAL: belum disetujui pemilik — diturunkan dari pola Plum gelap.
  static const _tealDark = <String, Color>{
    'hd': Color(0xFF0B2E2C),
    'pg': Color(0xFF1A1F1E),
    'card': Color(0xFF1E2826),
    'bd': Color(0xFF3A4440),
    'tx': Color(0xFFE8F0EE),
    'mu': Color(0xFFA0B0AD),
    'inc': Color(0xFF5EE0A8),
    'exp': Color(0xFFFF8FA3),
    'ac': Color(0xFFF2D3A0),
    'onac': Color(0xFF1E2826),
    'soft': Color(0xFF1A2B28),
    'chip': Color(0xFF144540),
    'nav': Color(0xFF1E2826),
    'persik': Color(0xFFF2D3A0),
    // #3F51B5 hanya 2.1:1 di atas card gelap; ikuti pola Plum gelap (#A9A4FF).
    'transfer': Color(0xFFA9A4FF),
    'onPersik': Color(0xFF0B2B2A),
  };

  static const _lunasBg = Color(0xFFD5F1E4);
  static const _lunasFg = Color(0xFF065F46);
  static const _telatBg = Color(0xFFFBDADF);
  static const _telatFg = Color(0xFF8F1D2C);
  static const _cicilBg = Color(0xFFFBE8C4);
  static const _cicilFg = Color(0xFF7A4A05);

  // Teks & nominal di atas kartu persik: mockup memakai warna gelap yang sama
  // pada tema terang dan gelap (kartu persik sendiri selalu terang).
  static const _onPersik = Color(0xFF2A1426);
  static const _incomeOnPersik = Color(0xFF065F46);
  static const _expenseOnPersik = Color(0xFF9F1239);

  static AppTokens plum(Brightness b) {
    final src = b == Brightness.dark ? _plumDark : _plumLight;
    return _fromMap(src);
  }

  static AppTokens teal(Brightness b) {
    final src = b == Brightness.dark ? _tealDark : _tealLight;
    return _fromMap(src);
  }

  static AppTokens _fromMap(Map<String, Color> s) {
    const onHeader = Colors.white;
    return AppTokens(
      headerBg: s['hd']!,
      headerFg: onHeader,
      headerMuted: s['hdm'] ?? onHeader.withValues(alpha: 0.72),
      headerSurface: onHeader.withValues(alpha: 0.20),
      headerBorder: onHeader.withValues(alpha: 0.45),
      pageBg: s['pg']!,
      card: s['card']!,
      softSurface: s['soft']!,
      softSurfaceStrong: Color.alphaBlend(
        s['ac']!.withValues(alpha: 0.18),
        s['card']!,
      ),
      textPrimary: s['tx']!,
      textMuted: s['mu']!,
      border: s['bd']!,
      accent: s['ac']!,
      onAccent: s['onac']!,
      income: s['inc']!,
      expense: s['exp']!,
      warning: const Color(0xFFFBBF24),
      incomeOnHeader: s['inc']!,
      expenseOnHeader: s['exp']!,
      transfer: s['transfer']!,
      chip: s['chip']!,
      nav: s['nav']!,
      persik: s['persik']!,
      lunasBg: _lunasBg,
      lunasFg: _lunasFg,
      telatBg: _telatBg,
      telatFg: _telatFg,
      cicilBg: _cicilBg,
      cicilFg: _cicilFg,
      onPersik: s['onPersik'] ?? _onPersik,
      incomeOnPersik: _incomeOnPersik,
      expenseOnPersik: _expenseOnPersik,
    );
  }

  // Keep fromScheme for custom mode (backward compat)
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _income = Color(0xFF10B981);
  static const Color _expense = Color(0xFFF43F5E);
  static const Color _warning = Color(0xFFFBBF24);
  static const Color _transfer = Color(0xFF3F51B5);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextMuted = Color(0xFF94A3B8);
  static const Color _darkBorder = Color(0xFF334155);
  static const Color _darkIncome = Color(0xFF34D399);
  static const Color _darkExpense = Color(0xFFFB7185);
  static const Color _darkWarning = Color(0xFFFCD34D);
  static const Color _darkTransfer = Color(0xFF818CF8);

  factory AppTokens.fromScheme(ColorScheme scheme, {required Color pageBg}) {
    final isDark = scheme.brightness == Brightness.dark;
    final onHeader = scheme.onPrimary;
    final card = isDark ? _darkCard : Colors.white;
    final income = isDark ? _darkIncome : _income;
    final expense = isDark ? _darkExpense : _expense;
    final accent = scheme.primary;
    return AppTokens(
      headerBg: scheme.primary,
      headerFg: onHeader,
      headerMuted: onHeader.withValues(alpha: 0.72),
      headerSurface: onHeader.withValues(alpha: 0.20),
      headerBorder: onHeader.withValues(alpha: 0.45),
      pageBg: pageBg,
      card: card,
      softSurface: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.22 : 0.10),
        card,
      ),
      softSurfaceStrong: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.34 : 0.18),
        card,
      ),
      textPrimary: isDark ? _darkTextPrimary : _textPrimary,
      textMuted: isDark ? _darkTextMuted : _textMuted,
      border: isDark ? _darkBorder : _border,
      accent: accent,
      onAccent: scheme.onPrimary,
      income: income,
      expense: expense,
      warning: isDark ? _darkWarning : _warning,
      incomeOnHeader: Color.lerp(income, onHeader, 0.30)!,
      expenseOnHeader: Color.lerp(expense, onHeader, 0.30)!,
      transfer: isDark ? _darkTransfer : _transfer,
      chip: isDark ? const Color(0xFF4A2A50) : const Color(0xFF52294A),
      nav: card,
      persik: const Color(0xFFF4C99A),
      lunasBg: _lunasBg,
      lunasFg: _lunasFg,
      telatBg: _telatBg,
      telatFg: _telatFg,
      cicilBg: _cicilBg,
      cicilFg: _cicilFg,
      onPersik: _onPersik,
      incomeOnPersik: _incomeOnPersik,
      expenseOnPersik: _expenseOnPersik,
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
    Color? chip,
    Color? nav,
    Color? persik,
    Color? lunasBg,
    Color? lunasFg,
    Color? telatBg,
    Color? telatFg,
    Color? cicilBg,
    Color? cicilFg,
    Color? onPersik,
    Color? incomeOnPersik,
    Color? expenseOnPersik,
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
      chip: chip ?? this.chip,
      nav: nav ?? this.nav,
      persik: persik ?? this.persik,
      lunasBg: lunasBg ?? this.lunasBg,
      lunasFg: lunasFg ?? this.lunasFg,
      telatBg: telatBg ?? this.telatBg,
      telatFg: telatFg ?? this.telatFg,
      cicilBg: cicilBg ?? this.cicilBg,
      cicilFg: cicilFg ?? this.cicilFg,
      onPersik: onPersik ?? this.onPersik,
      incomeOnPersik: incomeOnPersik ?? this.incomeOnPersik,
      expenseOnPersik: expenseOnPersik ?? this.expenseOnPersik,
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
      softSurfaceStrong: Color.lerp(
        softSurfaceStrong,
        other.softSurfaceStrong,
        t,
      )!,
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
      chip: Color.lerp(chip, other.chip, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      persik: Color.lerp(persik, other.persik, t)!,
      lunasBg: Color.lerp(lunasBg, other.lunasBg, t)!,
      lunasFg: Color.lerp(lunasFg, other.lunasFg, t)!,
      telatBg: Color.lerp(telatBg, other.telatBg, t)!,
      telatFg: Color.lerp(telatFg, other.telatFg, t)!,
      cicilBg: Color.lerp(cicilBg, other.cicilBg, t)!,
      cicilFg: Color.lerp(cicilFg, other.cicilFg, t)!,
      onPersik: Color.lerp(onPersik, other.onPersik, t)!,
      incomeOnPersik: Color.lerp(incomeOnPersik, other.incomeOnPersik, t)!,
      expenseOnPersik: Color.lerp(expenseOnPersik, other.expenseOnPersik, t)!,
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

abstract final class AppText {
  static const double micro = 10;
  static const double label = 11;
  static const double body = 12;
  static const double bodyLarge = 13;
  static const double subtitle = 14;
  static const double title = 16;
  static const double headline = 20;
  static const double display = 24;
  static const double displayLarge = 28;
  static const double stat = 32;
  static const double hero = 36;
}
