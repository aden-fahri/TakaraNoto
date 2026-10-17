import 'package:flutter/material.dart';

/// The two top-level modes of the app.
enum AppMode {
  personal('Pribadi'),
  group('Kelompok');

  const AppMode(this.label);

  final String label;
}

/// In-memory switch between the Pribadi and Kelompok shells.
///
/// The app always starts in [AppMode.personal]; the choice is deliberately
/// not persisted, so reopening the app lands on TakaraNoto again.
class AppModeController extends ChangeNotifier {
  AppModeController({AppMode initial = AppMode.personal}) : _mode = initial;

  AppMode _mode;

  AppMode get mode => _mode;

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
