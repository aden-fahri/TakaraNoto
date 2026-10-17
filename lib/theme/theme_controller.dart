import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A selectable color preset.
class ThemePreset {
  const ThemePreset(this.name, this.color);

  final String name;
  final Color color;
}

/// Holds the user's accent + background color choices and persists them.
///
/// Storage keys: `custom_primary_color` (int ARGB), `custom_background_color`.
/// Defaults: Plum Klasik accent + Krem Hangat background (tampilan lama).
class ThemeController extends ChangeNotifier {
  ThemeController();

  static const String prefKey = 'custom_primary_color';
  static const String backgroundPrefKey = 'custom_background_color';
  static const int defaultColorValue = 0xFF381932;
  static const int defaultBackgroundValue = 0xFFFFF3E6;

  static const List<ThemePreset> presets = [
    ThemePreset('Plum Klasik', Color(0xFF381932)),
    ThemePreset('Emerald Green', Color(0xFF059669)),
    ThemePreset('Electric Indigo', Color(0xFF4F46E5)),
    ThemePreset('Deep Navy', Color(0xFF1E3A8A)),
    ThemePreset('Royal Purple', Color(0xFF7C3AED)),
    ThemePreset('Warm Amber', Color(0xFFD97706)),
    ThemePreset('Rose Crimson', Color(0xFFE11D48)),
  ];

  static const List<ThemePreset> backgroundPresets = [
    ThemePreset('Krem Hangat', Color(0xFFFFF3E6)),
    ThemePreset('Slate Lembut', Color(0xFFF8FAFC)),
    ThemePreset('Putih Bersih', Color(0xFFFFFFFF)),
    ThemePreset('Abu Sejuk', Color(0xFFEEF2F6)),
  ];

  Color _seed = const Color(defaultColorValue);
  Color _background = const Color(defaultBackgroundValue);
  bool _isReady = false;

  Color get seed => _seed;
  Color get background => _background;
  bool get isReady => _isReady;

  /// True when the given color matches one of the built-in accent presets.
  bool isPresetSelected(Color color) =>
      presets.any((preset) => preset.color.toARGB32() == color.toARGB32());

  /// True when the given color matches one of the built-in background presets.
  bool isBackgroundPresetSelected(Color color) => backgroundPresets
      .any((preset) => preset.color.toARGB32() == color.toARGB32());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedSeed = prefs.getInt(prefKey);
      if (storedSeed != null) {
        _seed = Color(storedSeed);
      }
      final storedBackground = prefs.getInt(backgroundPrefKey);
      if (storedBackground != null) {
        _background = Color(storedBackground);
      }
    } catch (error) {
      debugPrint('ThemeController: gagal memuat warna tema: $error');
    }
    _isReady = true;
    notifyListeners();
  }

  Future<void> setSeed(Color color) async {
    if (color.toARGB32() == _seed.toARGB32()) return;
    _seed = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefKey, color.toARGB32());
    } catch (error) {
      debugPrint('ThemeController: gagal menyimpan warna tema: $error');
    }
  }

  Future<void> setBackground(Color color) async {
    if (color.toARGB32() == _background.toARGB32()) return;
    _background = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(backgroundPrefKey, color.toARGB32());
    } catch (error) {
      debugPrint('ThemeController: gagal menyimpan warna latar: $error');
    }
  }
}
