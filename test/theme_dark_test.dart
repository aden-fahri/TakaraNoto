import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('D6a: tema gelap memakai token & background gelap, terang tetap utuh',
      () {
    const seed = Color(0xFF381932);
    const background = Color(0xFFFFF3E6);

    final darkTheme = AppTheme.getTheme(seed, background, dark: true);
    final darkTokens = darkTheme.extension<AppTokens>()!;
    expect(darkTheme.scaffoldBackgroundColor.computeLuminance(), lessThan(0.2));
    expect(darkTokens.card.computeLuminance(), lessThan(0.2));
    expect(darkTokens.textPrimary.computeLuminance(), greaterThan(0.5));
    expect(darkTokens.textMuted.computeLuminance(), greaterThan(0.3));
    expect(darkTokens.border.computeLuminance(), lessThan(0.4));
    expect(darkTheme.colorScheme.brightness, Brightness.dark);

    final lightTheme = AppTheme.getTheme(seed, background);
    final lightTokens = lightTheme.extension<AppTokens>()!;
    expect(lightTheme.scaffoldBackgroundColor, background);
    expect(lightTokens.card, Colors.white);
    expect(lightTokens.textPrimary, const Color(0xFF0F172A));
  });

  test('D6a: ThemeController memuat & menyimpan preferensi mode gelap',
      () async {
    SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
    final controller = ThemeController();
    await controller.load();
    expect(controller.darkMode, isTrue);

    await controller.setDarkMode(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ThemeController.darkModePrefKey), isFalse);
    expect(controller.darkMode, isFalse);

    await controller.setDarkMode(true);
    expect(prefs.getBool(ThemeController.darkModePrefKey), isTrue);
  });
}
