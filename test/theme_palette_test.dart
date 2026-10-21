import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/theme/theme_controller.dart';

// Hex constants typed by hand from desain.md §3.1 (Plum) and §3.2 (Teal).
// Do NOT copy from code — these are the source-of-truth expectation.
const int _plumLightTx = 0xFF2A1426;
const int _plumLightMu = 0xFF6B5A68;
const int _plumLightInc = 0xFF047857;
const int _plumLightExp = 0xFFBE123C;
const int _plumLightAc = 0xFF381932;
const int _plumLightOnAc = 0xFFFFFFFF;
const int _plumLightSoft = 0xFFF4ECEF;
const int _plumLightChip = 0xFF52294A;
const int _plumLightNav = 0xFFFFFFFF;
const int _plumLightPersik = 0xFFF4C99A;
const int _plumLightHd = 0xFF381932;
const int _plumLightPg = 0xFFFFF3E6;
const int _plumLightCard = 0xFFFFFFFF;
const int _plumLightBd = 0xFFF0E4D6;
const int _plumLightTransfer = 0xFF3F51B5;
const int _plumLightLunasBg = 0xFFD5F1E4;
const int _plumLightLunasFg = 0xFF065F46;
const int _plumLightTelatBg = 0xFFFBDADF;
const int _plumLightTelatFg = 0xFF8F1D2C;
const int _plumLightCicilBg = 0xFFFBE8C4;
const int _plumLightCicilFg = 0xFF7A4A05;

// Baris atas header (mockup Main.dc.html: #E7CFE0; Dashboard-gelap: #D9C3D6)
const int _plumLightHeaderMuted = 0xFFE7CFE0;
const int _plumDarkHeaderMuted = 0xFFD9C3D6;
// Teks di atas kartu persik (mockup: #2A1426 terang & gelap; nominal #065F46/#9F1239)
const int _onPersik = 0xFF2A1426;
const int _incomeOnPersik = 0xFF065F46;
const int _expenseOnPersik = 0xFF9F1239;

const int _plumDarkTx = 0xFFF6EEF4;
const int _plumDarkMu = 0xFFB7A3B5;
const int _plumDarkInc = 0xFF5EE0A8;
const int _plumDarkExp = 0xFFFF8FA3;
const int _plumDarkAc = 0xFFF4C99A;
const int _plumDarkOnAc = 0xFF2A1426;
const int _plumDarkSoft = 0xFF382340;
const int _plumDarkChip = 0xFF4A2A50;
const int _plumDarkNav = 0xFF2A1A2E;
const int _plumDarkPersik = 0xFFF4C99A;
const int _plumDarkHd = 0xFF2B1530;
const int _plumDarkPg = 0xFF1D1020;
const int _plumDarkCard = 0xFF2A1A2E;
const int _plumDarkBd = 0xFF4A3050;

// Teal terang dari desain.md §3.2, onac dikoreksi kontras (lihat catatan).
const int _tealLightHd = 0xFF0F3D3A;
const int _tealLightPg = 0xFFF3F1EB;
const int _tealLightCard = 0xFFFBFAF7;
const int _tealLightBd = 0xFFE3DFD3;
const int _tealLightTx = 0xFF0B2B2A;
const int _tealLightMu = 0xFF5E6F6C;
const int _tealLightAc = 0xFF10B981;
// onac hasil koreksi kontras, bukan dari desain.md (§3.2 tidak menetapkan onac).
const int _tealLightOnAc = 0xFF0B2B2A;
const int _tealLightSoft = 0xFFE8EFEC;
const int _tealLightChip = 0xFF1C5A55;
const int _tealLightPersik = 0xFFF2D3A0;

double _lin(int v) {
  final s = v / 255.0;
  if (s <= 0.03928) return s / 12.92;
  return math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _relLum(Color c) {
  return 0.2126 * _lin((c.r * 255).round()) +
      0.7152 * _lin((c.g * 255).round()) +
      0.0722 * _lin((c.b * 255).round());
}

double _contrast(Color a, Color b) {
  final la = _relLum(a);
  final lb = _relLum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _expectContrast(Color fg, Color bg, String label) {
  final r = _contrast(fg, bg);
  // ignore: avoid_print
  print('CONTRAST $label = ${r.toStringAsFixed(2)}');
  expect(r, greaterThanOrEqualTo(4.5), reason: '$label contrast $r < 4.5');
}

void main() {
  group('AppTokens plum terang', () {
    test('tabel token sesuai desain.md §3.1', () {
      final t = AppTokens.plum(Brightness.light);
      expect(t.textPrimary.toARGB32(), _plumLightTx);
      expect(t.textMuted.toARGB32(), _plumLightMu);
      expect(t.income.toARGB32(), _plumLightInc);
      expect(t.expense.toARGB32(), _plumLightExp);
      expect(t.accent.toARGB32(), _plumLightAc);
      expect(t.onAccent.toARGB32(), _plumLightOnAc);
      expect(t.softSurface.toARGB32(), _plumLightSoft);
      expect(t.chip.toARGB32(), _plumLightChip);
      expect(t.nav.toARGB32(), _plumLightNav);
      expect(t.persik.toARGB32(), _plumLightPersik);
      expect(t.headerBg.toARGB32(), _plumLightHd);
      expect(t.pageBg.toARGB32(), _plumLightPg);
      expect(t.card.toARGB32(), _plumLightCard);
      expect(t.border.toARGB32(), _plumLightBd);
      expect(t.transfer.toARGB32(), _plumLightTransfer);
      expect(t.lunasBg.toARGB32(), _plumLightLunasBg);
      expect(t.lunasFg.toARGB32(), _plumLightLunasFg);
      expect(t.telatBg.toARGB32(), _plumLightTelatBg);
      expect(t.telatFg.toARGB32(), _plumLightTelatFg);
      expect(t.cicilBg.toARGB32(), _plumLightCicilBg);
      expect(t.cicilFg.toARGB32(), _plumLightCicilFg);
      expect(t.headerMuted.toARGB32(), _plumLightHeaderMuted);
      expect(t.onPersik.toARGB32(), _onPersik);
      expect(t.incomeOnPersik.toARGB32(), _incomeOnPersik);
      expect(t.expenseOnPersik.toARGB32(), _expenseOnPersik);
    });
  });

  group('AppTokens plum gelap', () {
    test('tabel token sesuai desain.md §3.1', () {
      final t = AppTokens.plum(Brightness.dark);
      expect(t.textPrimary.toARGB32(), _plumDarkTx);
      expect(t.textMuted.toARGB32(), _plumDarkMu);
      expect(t.income.toARGB32(), _plumDarkInc);
      expect(t.expense.toARGB32(), _plumDarkExp);
      expect(t.accent.toARGB32(), _plumDarkAc);
      expect(t.onAccent.toARGB32(), _plumDarkOnAc);
      expect(t.softSurface.toARGB32(), _plumDarkSoft);
      expect(t.chip.toARGB32(), _plumDarkChip);
      expect(t.nav.toARGB32(), _plumDarkNav);
      expect(t.persik.toARGB32(), _plumDarkPersik);
      expect(t.headerBg.toARGB32(), _plumDarkHd);
      expect(t.pageBg.toARGB32(), _plumDarkPg);
      expect(t.card.toARGB32(), _plumDarkCard);
      expect(t.border.toARGB32(), _plumDarkBd);
      expect(t.headerMuted.toARGB32(), _plumDarkHeaderMuted);
      expect(t.onPersik.toARGB32(), _onPersik);
      expect(t.incomeOnPersik.toARGB32(), _incomeOnPersik);
      expect(t.expenseOnPersik.toARGB32(), _expenseOnPersik);
    });
  });

  group('AppTokens teal terang', () {
    test('tabel token sesuai desain.md §3.2 (onac dikoreksi kontras)', () {
      final t = AppTokens.teal(Brightness.light);
      expect(t.headerBg.toARGB32(), _tealLightHd);
      expect(t.pageBg.toARGB32(), _tealLightPg);
      expect(t.card.toARGB32(), _tealLightCard);
      expect(t.border.toARGB32(), _tealLightBd);
      expect(t.textPrimary.toARGB32(), _tealLightTx);
      expect(t.textMuted.toARGB32(), _tealLightMu);
      expect(t.accent.toARGB32(), _tealLightAc);
      expect(t.onAccent.toARGB32(), _tealLightOnAc);
      expect(t.softSurface.toARGB32(), _tealLightSoft);
      expect(t.chip.toARGB32(), _tealLightChip);
      expect(t.persik.toARGB32(), _tealLightPersik);
    });
  });

  group('kontras WCAG (>=4.5)', () {
    void checkAll(AppTokens t, String name) {
      _expectContrast(t.textPrimary, t.card, '$name tx/card');
      _expectContrast(t.textPrimary, t.pageBg, '$name tx/pg');
      _expectContrast(t.textMuted, t.card, '$name mu/card');
      _expectContrast(t.textMuted, t.pageBg, '$name mu/pg');
      _expectContrast(t.onAccent, t.accent, '$name onac/ac');
      _expectContrast(t.headerFg, t.headerBg, '$name headerFg/hd');
      _expectContrast(t.headerMuted, t.headerBg, '$name headerMuted/hd');
      _expectContrast(t.onPersik, t.persik, '$name onPersik/persik');
      _expectContrast(t.incomeOnPersik, t.persik, '$name incOnPersik/persik');
      _expectContrast(t.expenseOnPersik, t.persik, '$name expOnPersik/persik');
      _expectContrast(t.lunasFg, t.lunasBg, '$name lunas');
      _expectContrast(t.telatFg, t.telatBg, '$name telat');
      _expectContrast(t.cicilFg, t.cicilBg, '$name cicil');
    }
    test('plum terang', () => checkAll(AppTokens.plum(Brightness.light), 'plum-light'));
    test('plum gelap', () => checkAll(AppTokens.plum(Brightness.dark), 'plum-dark'));
    test('teal terang', () => checkAll(AppTokens.teal(Brightness.light), 'teal-light'));
    test('teal gelap (PROVISIONAL)', () => checkAll(AppTokens.teal(Brightness.dark), 'teal-dark'));
  });

  group('ThemeController palet', () {
    test('tanpa data tersimpan -> Plum terang', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ThemeController();
      await c.load();
      expect(c.palette, ThemePalette.plum);
      expect(c.darkMode, false);
    });
    test('simpan lalu muat palet kembali sama', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ThemeController();
      await c.load();
      await c.setPalette(ThemePalette.teal);
      await c.setDarkMode(true);
      final c2 = ThemeController();
      await c2.load();
      expect(c2.palette, ThemePalette.teal);
      expect(c2.darkMode, true);
    });
  });
}
